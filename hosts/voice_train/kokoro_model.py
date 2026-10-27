"""kokoro_model.py - Kokoro-82M in PyTorch, for teaching it a voice (next/voice_engines.md, "Training Kokoro").

Adapted from hexgrad's kokoro 0.9.4 (Apache-2.0: kokoro/model.py, modules.py, istftnet.py), itself adapted from
yl4579's StyleTTS 2 (MIT). What changed: PL-BERT is ALBERT written out here (`Albert`, the state dict's own key
names), so neither `transformers` nor `huggingface_hub` is needed; the model loads from a path; and beside
`synthesize` (the inference forward, Kokoro's `forward_with_tokens`) it has the pieces a training step takes apart -
`encode` (the text, BERT and the predictor's encoder), `durations`, `prosody` (F0 and energy from aligned features)
and `decode` (the decoder, teacher-forced). Each module's code is Kokoro's line for line otherwise: the checkpoint
loads into it whole (`load`), and its output is the voice host's ONNX graph's (test_kokoro_train.py holds it).

THE FRAMES: a duration is in frames of 600 samples at 24 kHz (25 ms); the F0 and energy curves are at twice that
rate (300 samples); the decoder upsamples the aligned features by 2, then 10 x 6 x the iSTFT's hop of 5.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.nn.utils import weight_norm
from torch.utils.checkpoint import checkpoint

SR = 24000
HOP = 600  # samples a duration frame stands for
F0_HOP = 300  # samples an F0 or energy frame stands for


# --- PL-BERT: ALBERT, written out ------------------------------------------------------------------

def _gelu_new(x):
    return 0.5 * x * (1.0 + torch.tanh(math.sqrt(2.0 / math.pi) * (x + 0.044715 * torch.pow(x, 3.0))))


class _AlbertEmbeddings(nn.Module):
    def __init__(self, vocab, emb, max_pos, types=2, eps=1e-12):
        super().__init__()
        self.word_embeddings = nn.Embedding(vocab, emb, padding_idx=0)
        self.position_embeddings = nn.Embedding(max_pos, emb)
        self.token_type_embeddings = nn.Embedding(types, emb)
        self.LayerNorm = nn.LayerNorm(emb, eps=eps)
        self.dropout = nn.Dropout(0.0)

    def forward(self, ids):
        pos = torch.arange(ids.shape[1], device=ids.device)[None]
        x = self.word_embeddings(ids) + self.position_embeddings(pos) + self.token_type_embeddings(torch.zeros_like(ids))
        return self.dropout(self.LayerNorm(x))


class _AlbertAttention(nn.Module):
    def __init__(self, hidden, heads, eps=1e-12):
        super().__init__()
        self.heads = heads
        self.query = nn.Linear(hidden, hidden)
        self.key = nn.Linear(hidden, hidden)
        self.value = nn.Linear(hidden, hidden)
        self.dense = nn.Linear(hidden, hidden)
        self.LayerNorm = nn.LayerNorm(hidden, eps=eps)

    def forward(self, x, bias):
        b, t, c = x.shape
        split = lambda y: y.view(b, t, self.heads, c // self.heads).transpose(1, 2)  # noqa: E731
        q, k, v = split(self.query(x)), split(self.key(x)), split(self.value(x))
        att = torch.softmax(q @ k.transpose(-1, -2) / math.sqrt(c // self.heads) + bias, dim=-1)
        ctx = (att @ v).transpose(1, 2).reshape(b, t, c)
        return self.LayerNorm(x + self.dense(ctx))


class _AlbertLayer(nn.Module):
    def __init__(self, hidden, heads, inner, eps=1e-12):
        super().__init__()
        self.attention = _AlbertAttention(hidden, heads, eps)
        self.ffn = nn.Linear(hidden, inner)
        self.ffn_output = nn.Linear(inner, hidden)
        self.full_layer_layer_norm = nn.LayerNorm(hidden, eps=eps)

    def forward(self, x, bias):
        a = self.attention(x, bias)
        return self.full_layer_layer_norm(self.ffn_output(_gelu_new(self.ffn(a))) + a)


class _AlbertGroup(nn.Module):
    def __init__(self, hidden, heads, inner):
        super().__init__()
        self.albert_layers = nn.ModuleList([_AlbertLayer(hidden, heads, inner)])


class _AlbertTransformer(nn.Module):
    def __init__(self, emb, hidden, heads, inner, layers):
        super().__init__()
        self.layers = layers
        self.embedding_hidden_mapping_in = nn.Linear(emb, hidden)
        self.albert_layer_groups = nn.ModuleList([_AlbertGroup(hidden, heads, inner)])


class Albert(nn.Module):
    """HF's AlbertModel as PL-BERT uses it (one shared layer, 12 times; gelu_new; its key names), returning the
    last hidden state."""

    def __init__(self, vocab, hidden_size=768, num_attention_heads=12, intermediate_size=2048,
                 max_position_embeddings=512, num_hidden_layers=12, embedding_size=128, **_):
        super().__init__()
        self.max_position_embeddings = max_position_embeddings
        self.embeddings = _AlbertEmbeddings(vocab, embedding_size, max_position_embeddings)
        self.encoder = _AlbertTransformer(embedding_size, hidden_size, num_attention_heads, intermediate_size,
                                          num_hidden_layers)
        self.pooler = nn.Linear(hidden_size, hidden_size)  # in the checkpoint, never used

    def forward(self, ids, attention_mask):
        x = self.encoder.embedding_hidden_mapping_in(self.embeddings(ids))
        bias = (1.0 - attention_mask[:, None, None, :].to(x.dtype)) * torch.finfo(x.dtype).min
        layer = self.encoder.albert_layer_groups[0].albert_layers[0]
        for _ in range(self.encoder.layers):
            x = layer(x, bias)
        return x


# --- Kokoro's modules (kokoro/modules.py) -----------------------------------------------------------

class LinearNorm(nn.Module):
    def __init__(self, in_dim, out_dim, bias=True):
        super().__init__()
        self.linear_layer = nn.Linear(in_dim, out_dim, bias=bias)

    def forward(self, x):
        return self.linear_layer(x)


class LayerNorm(nn.Module):
    def __init__(self, channels, eps=1e-5):
        super().__init__()
        self.channels = channels
        self.eps = eps
        self.gamma = nn.Parameter(torch.ones(channels))
        self.beta = nn.Parameter(torch.zeros(channels))

    def forward(self, x):
        x = x.transpose(1, -1)
        x = F.layer_norm(x, (self.channels,), self.gamma, self.beta, self.eps)
        return x.transpose(1, -1)


def _lstm(lstm, x, lengths):
    """[B, T, C] through a bidirectional LSTM, each row for its own length; padded back to T."""
    t = x.shape[1]
    packed = nn.utils.rnn.pack_padded_sequence(x, lengths.cpu(), batch_first=True, enforce_sorted=False)
    lstm.flatten_parameters()
    y, _ = lstm(packed)
    y, _ = nn.utils.rnn.pad_packed_sequence(y, batch_first=True, total_length=t)
    return y


class TextEncoder(nn.Module):
    def __init__(self, channels, kernel_size, depth, n_symbols, actv=nn.LeakyReLU(0.2)):
        super().__init__()
        self.embedding = nn.Embedding(n_symbols, channels)
        padding = (kernel_size - 1) // 2
        self.cnn = nn.ModuleList()
        for _ in range(depth):
            self.cnn.append(nn.Sequential(
                weight_norm(nn.Conv1d(channels, channels, kernel_size=kernel_size, padding=padding)),
                LayerNorm(channels), actv, nn.Dropout(0.2)))
        self.lstm = nn.LSTM(channels, channels // 2, 1, batch_first=True, bidirectional=True)

    def forward(self, x, input_lengths, m):
        x = self.embedding(x).transpose(1, 2)
        m = m.unsqueeze(1)
        x = x.masked_fill(m, 0.0)
        for c in self.cnn:
            x = c(x).masked_fill(m, 0.0)
        x = _lstm(self.lstm, x.transpose(1, 2), input_lengths).transpose(-1, -2)
        return x.masked_fill(m, 0.0)


class AdaLayerNorm(nn.Module):
    def __init__(self, style_dim, channels, eps=1e-5):
        super().__init__()
        self.channels = channels
        self.eps = eps
        self.fc = nn.Linear(style_dim, channels * 2)

    def forward(self, x, s):
        x = x.transpose(-1, -2).transpose(1, -1)
        h = self.fc(s)
        h = h.view(h.size(0), h.size(1), 1)
        gamma, beta = torch.chunk(h, chunks=2, dim=1)
        gamma, beta = gamma.transpose(1, -1), beta.transpose(1, -1)
        x = F.layer_norm(x, (self.channels,), eps=self.eps)
        x = (1 + gamma) * x + beta
        return x.transpose(1, -1).transpose(-1, -2)


class DurationEncoder(nn.Module):
    def __init__(self, sty_dim, d_model, nlayers, dropout=0.1):
        super().__init__()
        self.lstms = nn.ModuleList()
        for _ in range(nlayers):
            self.lstms.append(nn.LSTM(d_model + sty_dim, d_model // 2, num_layers=1, batch_first=True,
                                      bidirectional=True))
            self.lstms.append(AdaLayerNorm(sty_dim, d_model))
        self.dropout = dropout

    def forward(self, x, style, text_lengths, m):
        # x [B, C, T], style [B, S] -> [B, T, C + S]
        s = style[:, :, None].expand(-1, -1, x.shape[-1])
        mask = m[:, None, :]
        x = torch.cat([x, s], dim=1).masked_fill(mask, 0.0)
        for block in self.lstms:
            if isinstance(block, AdaLayerNorm):
                x = block(x.transpose(-1, -2), style).transpose(-1, -2)
                x = torch.cat([x, s], dim=1).masked_fill(mask, 0.0)
            else:
                x = _lstm(block, x.transpose(-1, -2), text_lengths).transpose(-1, -2)
        return x.transpose(-1, -2)


class ProsodyPredictor(nn.Module):
    def __init__(self, style_dim, d_hid, nlayers, max_dur=50, dropout=0.1):
        super().__init__()
        self.text_encoder = DurationEncoder(sty_dim=style_dim, d_model=d_hid, nlayers=nlayers, dropout=dropout)
        self.lstm = nn.LSTM(d_hid + style_dim, d_hid // 2, 1, batch_first=True, bidirectional=True)
        self.duration_proj = LinearNorm(d_hid, max_dur)
        self.shared = nn.LSTM(d_hid + style_dim, d_hid // 2, 1, batch_first=True, bidirectional=True)
        self.F0 = nn.ModuleList([
            AdainResBlk1d(d_hid, d_hid, style_dim, dropout_p=dropout),
            AdainResBlk1d(d_hid, d_hid // 2, style_dim, upsample=True, dropout_p=dropout),
            AdainResBlk1d(d_hid // 2, d_hid // 2, style_dim, dropout_p=dropout)])
        self.N = nn.ModuleList([
            AdainResBlk1d(d_hid, d_hid, style_dim, dropout_p=dropout),
            AdainResBlk1d(d_hid, d_hid // 2, style_dim, upsample=True, dropout_p=dropout),
            AdainResBlk1d(d_hid // 2, d_hid // 2, style_dim, dropout_p=dropout)])
        self.F0_proj = nn.Conv1d(d_hid // 2, 1, 1, 1, 0)
        self.N_proj = nn.Conv1d(d_hid // 2, 1, 1, 1, 0)

    def F0Ntrain(self, x, s, lengths=None):
        """F0 and energy at twice the frame rate from aligned features `x` [B, C, frames]."""
        if lengths is None:
            x, _ = self.shared(x.transpose(-1, -2))
        else:
            x = _lstm(self.shared, x.transpose(-1, -2), lengths)
        f0 = x.transpose(-1, -2)
        for block in self.F0:
            f0 = block(f0, s)
        n = x.transpose(-1, -2)
        for block in self.N:
            n = block(n, s)
        return self.F0_proj(f0).squeeze(1), self.N_proj(n).squeeze(1)


# --- the decoder (kokoro/istftnet.py) ----------------------------------------------------------------

def _get_padding(kernel_size, dilation=1):
    return int((kernel_size * dilation - dilation) / 2)


class AdaIN1d(nn.Module):
    def __init__(self, style_dim, num_features):
        super().__init__()
        # affine=True as Kokoro has it (an old ONNX exporter's bug): its weight and bias are not in the checkpoint
        self.norm = nn.InstanceNorm1d(num_features, affine=True)
        self.fc = nn.Linear(style_dim, num_features * 2)

    def forward(self, x, s):
        h = self.fc(s)
        h = h.view(h.size(0), h.size(1), 1)
        gamma, beta = torch.chunk(h, chunks=2, dim=1)
        return (1 + gamma) * self.norm(x) + beta


class AdaINResBlock1(nn.Module):
    def __init__(self, channels, kernel_size=3, dilation=(1, 3, 5), style_dim=64):
        super().__init__()
        self.convs1 = nn.ModuleList([
            weight_norm(nn.Conv1d(channels, channels, kernel_size, 1, dilation=d, padding=_get_padding(kernel_size, d)))
            for d in dilation])
        self.convs2 = nn.ModuleList([
            weight_norm(nn.Conv1d(channels, channels, kernel_size, 1, dilation=1, padding=_get_padding(kernel_size, 1)))
            for _ in dilation])
        self.adain1 = nn.ModuleList([AdaIN1d(style_dim, channels) for _ in dilation])
        self.adain2 = nn.ModuleList([AdaIN1d(style_dim, channels) for _ in dilation])
        self.alpha1 = nn.ParameterList([nn.Parameter(torch.ones(1, channels, 1)) for _ in dilation])
        self.alpha2 = nn.ParameterList([nn.Parameter(torch.ones(1, channels, 1)) for _ in dilation])

    def forward(self, x, s):
        for c1, c2, n1, n2, a1, a2 in zip(self.convs1, self.convs2, self.adain1, self.adain2, self.alpha1, self.alpha2):
            xt = n1(x, s)
            xt = xt + (1 / a1) * (torch.sin(a1 * xt) ** 2)  # Snake1D
            xt = c1(xt)
            xt = n2(xt, s)
            xt = xt + (1 / a2) * (torch.sin(a2 * xt) ** 2)
            xt = c2(xt)
            x = xt + x
        return x


class TorchSTFT(nn.Module):
    def __init__(self, filter_length=800, hop_length=200, win_length=800):
        super().__init__()
        self.filter_length = filter_length
        self.hop_length = hop_length
        self.win_length = win_length
        self.register_buffer("window", torch.hann_window(win_length, periodic=True, dtype=torch.float32),
                             persistent=False)

    def transform(self, x):
        z = torch.stft(x, self.filter_length, self.hop_length, self.win_length, window=self.window, return_complex=True)
        return torch.abs(z), torch.angle(z)

    def inverse(self, magnitude, phase):
        y = torch.istft(magnitude * torch.exp(phase * 1j), self.filter_length, self.hop_length, self.win_length,
                        window=self.window)
        return y.unsqueeze(-2)


class SineGen(nn.Module):
    def __init__(self, samp_rate, upsample_scale, harmonic_num=0, sine_amp=0.1, noise_std=0.003, voiced_threshold=0):
        super().__init__()
        self.sine_amp = sine_amp
        self.noise_std = noise_std
        self.harmonic_num = harmonic_num
        self.dim = harmonic_num + 1
        self.sampling_rate = samp_rate
        self.voiced_threshold = voiced_threshold
        self.upsample_scale = upsample_scale

    def _f02sine(self, f0_values):
        rad_values = (f0_values / self.sampling_rate) % 1
        rand_ini = torch.rand(f0_values.shape[0], f0_values.shape[2], device=f0_values.device)
        rand_ini[:, 0] = 0
        rad_values[:, 0, :] = rad_values[:, 0, :] + rand_ini
        rad_values = F.interpolate(rad_values.transpose(1, 2), scale_factor=1 / self.upsample_scale,
                                   mode="linear").transpose(1, 2)
        phase = torch.cumsum(rad_values, dim=1) * 2 * torch.pi
        phase = F.interpolate(phase.transpose(1, 2) * self.upsample_scale, scale_factor=self.upsample_scale,
                              mode="linear").transpose(1, 2)
        return torch.sin(phase)

    def forward(self, f0):
        fn = f0 * torch.arange(1, self.harmonic_num + 2, device=f0.device, dtype=f0.dtype)[None, None, :]
        sine_waves = self._f02sine(fn) * self.sine_amp
        uv = (f0 > self.voiced_threshold).to(torch.float32)
        noise_amp = uv * self.noise_std + (1 - uv) * self.sine_amp / 3
        noise = noise_amp * torch.randn_like(sine_waves)
        return sine_waves * uv + noise, uv, noise


class SourceModuleHnNSF(nn.Module):
    def __init__(self, sampling_rate, upsample_scale, harmonic_num=0, sine_amp=0.1, add_noise_std=0.003,
                 voiced_threshod=0):
        super().__init__()
        self.sine_amp = sine_amp
        self.l_sin_gen = SineGen(sampling_rate, upsample_scale, harmonic_num, sine_amp, add_noise_std, voiced_threshod)
        self.l_linear = nn.Linear(harmonic_num + 1, 1)
        self.l_tanh = nn.Tanh()

    def forward(self, x):
        with torch.no_grad():
            sine_wavs, uv, _ = self.l_sin_gen(x)
        sine_merge = self.l_tanh(self.l_linear(sine_wavs))
        noise = torch.randn_like(uv) * self.sine_amp / 3
        return sine_merge, noise, uv


class Generator(nn.Module):
    def __init__(self, style_dim, resblock_kernel_sizes, upsample_rates, upsample_initial_channel,
                 resblock_dilation_sizes, upsample_kernel_sizes, gen_istft_n_fft, gen_istft_hop_size):
        super().__init__()
        self.num_kernels = len(resblock_kernel_sizes)
        self.num_upsamples = len(upsample_rates)
        self.m_source = SourceModuleHnNSF(sampling_rate=SR, upsample_scale=math.prod(upsample_rates) * gen_istft_hop_size,
                                          harmonic_num=8, voiced_threshod=10)
        self.f0_upsamp = nn.Upsample(scale_factor=math.prod(upsample_rates) * gen_istft_hop_size)
        self.noise_convs = nn.ModuleList()
        self.noise_res = nn.ModuleList()
        self.ups = nn.ModuleList()
        for i, (u, k) in enumerate(zip(upsample_rates, upsample_kernel_sizes)):
            self.ups.append(weight_norm(nn.ConvTranspose1d(upsample_initial_channel // (2 ** i),
                                                           upsample_initial_channel // (2 ** (i + 1)), k, u,
                                                           padding=(k - u) // 2)))
        self.resblocks = nn.ModuleList()
        ch = upsample_initial_channel
        for i in range(len(self.ups)):
            ch = upsample_initial_channel // (2 ** (i + 1))
            for k, d in zip(resblock_kernel_sizes, resblock_dilation_sizes):
                self.resblocks.append(AdaINResBlock1(ch, k, d, style_dim))
            if i + 1 < len(upsample_rates):
                stride_f0 = math.prod(upsample_rates[i + 1:])
                self.noise_convs.append(nn.Conv1d(gen_istft_n_fft + 2, ch, kernel_size=stride_f0 * 2, stride=stride_f0,
                                                  padding=(stride_f0 + 1) // 2))
                self.noise_res.append(AdaINResBlock1(ch, 7, [1, 3, 5], style_dim))
            else:
                self.noise_convs.append(nn.Conv1d(gen_istft_n_fft + 2, ch, kernel_size=1))
                self.noise_res.append(AdaINResBlock1(ch, 11, [1, 3, 5], style_dim))
        self.post_n_fft = gen_istft_n_fft
        self.conv_post = weight_norm(nn.Conv1d(ch, self.post_n_fft + 2, 7, 1, padding=3))
        self.reflection_pad = nn.ReflectionPad1d((1, 0))
        self.stft = TorchSTFT(filter_length=gen_istft_n_fft, hop_length=gen_istft_hop_size, win_length=gen_istft_n_fft)

    def forward(self, x, s, f0):
        with torch.no_grad():
            f0 = self.f0_upsamp(f0[:, None]).transpose(1, 2)
            har_source, _noise, _uv = self.m_source(f0)
            har_spec, har_phase = self.stft.transform(har_source.transpose(1, 2).squeeze(1))
            har = torch.cat([har_spec, har_phase], dim=1)
        # TAUGHT, THE RESIDUAL BLOCKS ARE WORKED OUT AGAIN BACKWARD rather than kept: their Snakes keep a dozen tensors
        # a block at 4,800 steps a second, 6 GB for eight 1.5 s stretches, and the run died of it on a 16 GB card
        keep = self.training and torch.is_grad_enabled()
        run = (lambda blk, *a: checkpoint(blk, *a, use_reentrant=False)) if keep else (lambda blk, *a: blk(*a))  # noqa: E731
        for i in range(self.num_upsamples):
            x = F.leaky_relu(x, negative_slope=0.1)
            x_source = run(self.noise_res[i], self.noise_convs[i](har), s)
            x = self.ups[i](x)
            if i == self.num_upsamples - 1:
                x = self.reflection_pad(x)
            x = x + x_source
            xs = None
            for j in range(self.num_kernels):
                r = run(self.resblocks[i * self.num_kernels + j], x, s)
                xs = r if xs is None else xs + r
            x = xs / self.num_kernels
        x = self.conv_post(F.leaky_relu(x))
        spec = torch.exp(x[:, :self.post_n_fft // 2 + 1, :])
        phase = torch.sin(x[:, self.post_n_fft // 2 + 1:, :])
        return self.stft.inverse(spec, phase)


class UpSample1d(nn.Module):
    def __init__(self, layer_type):
        super().__init__()
        self.layer_type = layer_type

    def forward(self, x):
        return x if self.layer_type == "none" else F.interpolate(x, scale_factor=2, mode="nearest")


class AdainResBlk1d(nn.Module):
    def __init__(self, dim_in, dim_out, style_dim=64, actv=nn.LeakyReLU(0.2), upsample="none", dropout_p=0.0):
        super().__init__()
        self.actv = actv
        self.upsample_type = upsample
        self.upsample = UpSample1d(upsample)
        self.learned_sc = dim_in != dim_out
        self.conv1 = weight_norm(nn.Conv1d(dim_in, dim_out, 3, 1, 1))
        self.conv2 = weight_norm(nn.Conv1d(dim_out, dim_out, 3, 1, 1))
        self.norm1 = AdaIN1d(style_dim, dim_in)
        self.norm2 = AdaIN1d(style_dim, dim_out)
        if self.learned_sc:
            self.conv1x1 = weight_norm(nn.Conv1d(dim_in, dim_out, 1, 1, 0, bias=False))
        self.dropout = nn.Dropout(dropout_p)
        if upsample == "none":
            self.pool = nn.Identity()
        else:
            self.pool = weight_norm(nn.ConvTranspose1d(dim_in, dim_in, kernel_size=3, stride=2, groups=dim_in, padding=1,
                                                       output_padding=1))

    def _shortcut(self, x):
        x = self.upsample(x)
        return self.conv1x1(x) if self.learned_sc else x

    def _residual(self, x, s):
        x = self.pool(self.actv(self.norm1(x, s)))
        x = self.conv1(self.dropout(x))
        x = self.conv2(self.dropout(self.actv(self.norm2(x, s))))
        return x

    def forward(self, x, s):
        return (self._residual(x, s) + self._shortcut(x)) * (1.0 / math.sqrt(2.0))


class Decoder(nn.Module):
    def __init__(self, dim_in, style_dim, dim_out, resblock_kernel_sizes, upsample_rates, upsample_initial_channel,
                 resblock_dilation_sizes, upsample_kernel_sizes, gen_istft_n_fft, gen_istft_hop_size):
        super().__init__()
        self.encode = AdainResBlk1d(dim_in + 2, 1024, style_dim)
        self.decode = nn.ModuleList([
            AdainResBlk1d(1024 + 2 + 64, 1024, style_dim),
            AdainResBlk1d(1024 + 2 + 64, 1024, style_dim),
            AdainResBlk1d(1024 + 2 + 64, 1024, style_dim),
            AdainResBlk1d(1024 + 2 + 64, 512, style_dim, upsample=True)])
        self.F0_conv = weight_norm(nn.Conv1d(1, 1, kernel_size=3, stride=2, groups=1, padding=1))
        self.N_conv = weight_norm(nn.Conv1d(1, 1, kernel_size=3, stride=2, groups=1, padding=1))
        self.asr_res = nn.Sequential(weight_norm(nn.Conv1d(512, 64, kernel_size=1)))
        self.generator = Generator(style_dim, resblock_kernel_sizes, upsample_rates, upsample_initial_channel,
                                   resblock_dilation_sizes, upsample_kernel_sizes, gen_istft_n_fft, gen_istft_hop_size)

    def forward(self, asr, F0_curve, N, s):
        F0 = self.F0_conv(F0_curve.unsqueeze(1))
        N = self.N_conv(N.unsqueeze(1))
        x = self.encode(torch.cat([asr, F0, N], dim=1), s)
        asr_res = self.asr_res(asr)
        res = True
        for block in self.decode:
            if res:
                x = torch.cat([x, asr_res, F0, N], dim=1)
            x = block(x, s)
            if block.upsample_type != "none":
                res = False
        return self.generator(x, s, F0_curve)


# --- the model -------------------------------------------------------------------------------------

class KModel(nn.Module):
    """Kokoro: PL-BERT and its projection, the prosody predictor, the text encoder and the decoder."""

    def __init__(self, config: dict):
        super().__init__()
        self.vocab = config["vocab"]
        self.bert = Albert(config["n_token"], **config["plbert"])
        self.bert_encoder = nn.Linear(config["plbert"]["hidden_size"], config["hidden_dim"])
        self.predictor = ProsodyPredictor(style_dim=config["style_dim"], d_hid=config["hidden_dim"],
                                          nlayers=config["n_layer"], max_dur=config["max_dur"],
                                          dropout=config["dropout"])
        self.text_encoder = TextEncoder(channels=config["hidden_dim"], kernel_size=config["text_encoder_kernel_size"],
                                        depth=config["n_layer"], n_symbols=config["n_token"])
        self.decoder = Decoder(dim_in=config["hidden_dim"], style_dim=config["style_dim"], dim_out=config["n_mels"],
                               **config["istftnet"])

    PARTS = ("bert", "bert_encoder", "predictor", "text_encoder", "decoder")

    @classmethod
    def load(cls, weights: str | Path, config: str | Path) -> "KModel":
        """The checkpoint (a dict of the five parts' state dicts, keys under "module.") into the model. Only the
        AdaIN norms' affine weights may be missing (Kokoro's own loader is lenient the same way): anything else
        missing or left over is an error."""
        model = cls(json.loads(Path(config).read_text(encoding="utf-8")))
        state = torch.load(weights, map_location="cpu", weights_only=True)
        for part in cls.PARTS:
            sd = {k[7:] if k.startswith("module.") else k: v for k, v in state[part].items()}
            missing, extra = getattr(model, part).load_state_dict(sd, strict=False)
            missing = [k for k in missing if not (".norm.weight" in k or ".norm.bias" in k)]
            extra = [k for k in extra if not k.endswith("position_ids")]
            if missing or extra:
                raise ValueError("%s: missing %s, unexpected %s" % (part, missing[:5], extra[:5]))
        return model

    @staticmethod
    def masks(lengths: torch.Tensor, t: int) -> torch.Tensor:
        """True past each row's length."""
        return torch.arange(t, device=lengths.device)[None, :] >= lengths[:, None]

    def encode(self, ids, lengths, style_p):
        """The text, read: `d` [B, T, 640] (the predictor's encoder, prosody style attached), `t_en` [B, 512, T]
        (the decoder's text encoder) and the duration logits [B, T, 50]."""
        m = self.masks(lengths, ids.shape[1])
        bert = self.bert(ids, attention_mask=(~m).int())
        d_en = self.bert_encoder(bert).transpose(-1, -2)
        d = self.predictor.text_encoder(d_en, style_p, lengths, m)
        x = _lstm(self.predictor.lstm, d, lengths)
        logits = self.predictor.duration_proj(x)
        t_en = self.text_encoder(ids, lengths, m)
        return d, t_en, logits

    @staticmethod
    def durations(logits, speed: float = 1.0):
        """The planned frames per token, unrounded: the sum of the sigmoids, over the speed."""
        return torch.sigmoid(logits).sum(dim=-1) / speed

    @staticmethod
    def alignment(frames: torch.Tensor, total: int) -> torch.Tensor:
        """Hard alignment [T, total] from whole frames per token (a token of 0 frames takes none)."""
        idx = torch.repeat_interleave(torch.arange(frames.shape[0], device=frames.device), frames)
        aln = torch.zeros(frames.shape[0], total, device=frames.device)
        aln[idx[:total], torch.arange(min(total, idx.shape[0]), device=frames.device)] = 1
        return aln

    def prosody(self, d, aln, style_p, frame_lengths=None):
        """F0 and energy [B, 2 x frames] from the predictor's encoding `d` [B, T, C] and alignment [B, T, frames]."""
        en = d.transpose(-1, -2) @ aln
        return self.predictor.F0Ntrain(en, style_p, frame_lengths)

    def decode(self, t_en, aln, f0, n, style_d):
        """The decoder, teacher-forced: audio [B, frames x 600] from the text encoding, its alignment, F0 and energy."""
        return self.decoder(t_en @ aln, f0, n, style_d).squeeze(1)

    @torch.no_grad()
    def plan_of(self, ids: torch.Tensor, ref_s: torch.Tensor, speed: float = 1.0):
        """What Kokoro plans for a sentence, nothing decoded: (frames per token, F0, energy), as `synthesize` plans."""
        lengths = torch.tensor([ids.shape[1]], device=ids.device)
        d, _t_en, logits = self.encode(ids, lengths, ref_s[:, 128:])
        frames = torch.round(self.durations(logits, speed)).clamp(min=1).long().squeeze(0)
        f0, n = self.prosody(d, self.alignment(frames, int(frames.sum()))[None], ref_s[:, 128:])
        return frames.cpu().numpy(), f0[0].cpu().numpy(), n[0].cpu().numpy()

    @torch.no_grad()
    def synthesize(self, ids: torch.Tensor, ref_s: torch.Tensor, speed: float = 1.0):
        """One sentence, as Kokoro's `forward_with_tokens`: ids [1, T] (pads at both ends included), ref_s [1, 256].
        Returns (audio [samples], frames per token)."""
        lengths = torch.tensor([ids.shape[1]], device=ids.device)
        s_p, s_d = ref_s[:, 128:], ref_s[:, :128]
        d, t_en, logits = self.encode(ids, lengths, s_p)
        frames = torch.round(self.durations(logits, speed)).clamp(min=1).long().squeeze(0)
        aln = self.alignment(frames, int(frames.sum()))[None]
        f0, n = self.prosody(d, aln, s_p)
        return self.decode(t_en, aln, f0, n, s_d).squeeze(0), frames
