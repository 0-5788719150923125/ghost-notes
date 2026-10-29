"""wavlm.py - WavLM Base+ in PyTorch, as an ear for teaching Kokoro (next/voice_engines.md, "kikiri-tts read again").

StyleTTS 2 teaches its decoder with a speech model listening (`WavLMLoss`, losses.py): its audio and the recording
through WavLM Base+, the L1 between their 13 hidden states summed - what a frame-by-frame mel loss cannot hear, a stop
said or smeared. This is that ear without `transformers`: WavLM written out from transformers' modeling_wavlm.py (the
13 states as transformers 4.x and StyleTTS 2 read them: the features after the positional convolution and the norm,
then each of the 12 layers), its state dict's own key names, loaded from microsoft/wavlm-base-plus's
pytorch_model.bin (CC BY-SA 3.0 - UniSpeech's license; used to teach, never part of a voice); and torchaudio's
24 to 16 kHz resampling (`Resample`'s Hann-windowed sinc, width 6, rolloff 0.99), as StyleTTS 2 resamples. Eval mode
throughout, as StyleTTS 2 holds it: no dropout, no masking. Checked against transformers' WavLMModel (5.x,
2026-10-27, three seconds of a recording): every one of the 13 states within 3e-5 of its own.
"""

from __future__ import annotations

import math
from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F

HIDDEN = 768
HEADS = 12
INNER = 3072
LAYERS = 12
CONV = ((10, 5), (3, 2), (3, 2), (3, 2), (3, 2), (2, 2), (2, 2))  # (kernel, stride), 512 channels each
POS_KERNEL = 128
POS_GROUPS = 16
BUCKETS = 320
MAX_DISTANCE = 800
EPS = 1e-5


class _ConvLayer(nn.Module):
    def __init__(self, cin, kernel, stride, norm):
        super().__init__()
        self.conv = nn.Conv1d(cin, 512, kernel, stride, bias=False)
        if norm:
            self.layer_norm = nn.GroupNorm(512, 512, affine=True)

    def forward(self, x):
        x = self.conv(x)
        if hasattr(self, "layer_norm"):
            x = self.layer_norm(x)
        return F.gelu(x)


class _FeatureExtractor(nn.Module):
    def __init__(self):
        super().__init__()
        self.conv_layers = nn.ModuleList([_ConvLayer(1 if i == 0 else 512, k, s, i == 0) for i, (k, s) in enumerate(CONV)])

    def forward(self, wav):
        x = wav[:, None]
        for layer in self.conv_layers:
            x = layer(x)
        return x


class _FeatureProjection(nn.Module):
    def __init__(self):
        super().__init__()
        self.layer_norm = nn.LayerNorm(512, eps=EPS)
        self.projection = nn.Linear(512, HIDDEN)

    def forward(self, x):
        return self.projection(self.layer_norm(x))


class _PositionalConv(nn.Module):
    def __init__(self):
        super().__init__()
        # weight norm folded at load (`WavLM.load`): the checkpoint's weight_g and weight_v
        self.conv = nn.Conv1d(HIDDEN, HIDDEN, POS_KERNEL, padding=POS_KERNEL // 2, groups=POS_GROUPS)

    def forward(self, x):
        y = self.conv(x.transpose(1, 2))[:, :, :-1]  # an even kernel: one frame too many
        return F.gelu(y).transpose(1, 2)


class _Attention(nn.Module):
    def __init__(self, bias: bool):
        super().__init__()
        self.head = HIDDEN // HEADS
        self.k_proj = nn.Linear(HIDDEN, HIDDEN)
        self.v_proj = nn.Linear(HIDDEN, HIDDEN)
        self.q_proj = nn.Linear(HIDDEN, HIDDEN)
        self.out_proj = nn.Linear(HIDDEN, HIDDEN)
        self.gru_rel_pos_const = nn.Parameter(torch.ones(1, HEADS, 1, 1))
        self.gru_rel_pos_linear = nn.Linear(self.head, 8)
        if bias:
            self.rel_attn_embed = nn.Embedding(BUCKETS, HEADS)

    def position_bias(self, t: int, device) -> torch.Tensor:
        """[HEADS, t, t]: T5's log buckets of the key's place less the query's."""
        rel = torch.arange(t, device=device)[None, :] - torch.arange(t, device=device)[:, None]
        half = BUCKETS // 2
        bucket = (rel > 0).long() * half
        rel = rel.abs()
        exact = half // 2
        large = exact + (torch.log(rel.float() / exact) / math.log(MAX_DISTANCE / exact) * (half - exact)).long()
        bucket = bucket + torch.where(rel < exact, rel, large.clamp(max=half - 1))
        return self.rel_attn_embed(bucket).permute(2, 0, 1)

    def forward(self, x, bias):
        b, t, _ = x.shape
        # the bias gated by each head's own reading of each frame
        g = self.gru_rel_pos_linear(x.view(b, t, HEADS, self.head).permute(0, 2, 1, 3))
        gate_a, gate_b = torch.sigmoid(g.view(b, HEADS, t, 2, 4).sum(-1)).chunk(2, dim=-1)
        gated = (gate_a * (gate_b * self.gru_rel_pos_const - 1.0) + 2.0) * bias[None]
        split = lambda z: z.view(b, t, HEADS, self.head).transpose(1, 2)  # noqa: E731
        q = split(self.q_proj(x)) * self.head ** -0.5
        k, v = split(self.k_proj(x)), split(self.v_proj(x))
        att = torch.softmax(q @ k.transpose(-1, -2) + gated, dim=-1)
        return self.out_proj((att @ v).transpose(1, 2).reshape(b, t, HIDDEN))


class _FeedForward(nn.Module):
    def __init__(self):
        super().__init__()
        self.intermediate_dense = nn.Linear(HIDDEN, INNER)
        self.output_dense = nn.Linear(INNER, HIDDEN)

    def forward(self, x):
        return self.output_dense(F.gelu(self.intermediate_dense(x)))


class _Layer(nn.Module):
    def __init__(self, bias: bool):
        super().__init__()
        self.attention = _Attention(bias)
        self.layer_norm = nn.LayerNorm(HIDDEN, eps=EPS)
        self.feed_forward = _FeedForward()
        self.final_layer_norm = nn.LayerNorm(HIDDEN, eps=EPS)

    def forward(self, x, bias):
        x = self.layer_norm(x + self.attention(x, bias))
        return self.final_layer_norm(x + self.feed_forward(x))


class _Encoder(nn.Module):
    def __init__(self):
        super().__init__()
        self.pos_conv_embed = _PositionalConv()
        self.layer_norm = nn.LayerNorm(HIDDEN, eps=EPS)
        self.layers = nn.ModuleList([_Layer(i == 0) for i in range(LAYERS)])


class WavLM(nn.Module):
    """WavLM Base+: 16 kHz audio [B, samples] to its 13 hidden states, each [B, frames, 768] (a frame 20 ms)."""

    def __init__(self):
        super().__init__()
        self.feature_extractor = _FeatureExtractor()
        self.feature_projection = _FeatureProjection()
        self.encoder = _Encoder()

    @classmethod
    def load(cls, weights: str | Path) -> "WavLM":
        """pytorch_model.bin into the model, the positional convolution's weight norm folded (norm over all but the
        kernel's axis); its masking embedding, unused at eval, left out. Anything else missing or left over is an
        error."""
        model = cls()
        model.load_state_dict(folded(torch.load(weights, map_location="cpu", weights_only=True)), strict=True)
        return model.eval()

    def forward(self, wav16):
        x = self.feature_projection(self.feature_extractor(wav16).transpose(1, 2))
        enc = self.encoder
        x = enc.layer_norm(x + enc.pos_conv_embed(x))
        states = [x]
        bias = enc.layers[0].attention.position_bias(x.shape[1], x.device)
        for layer in enc.layers:
            x = layer(x, bias)
            states.append(x)
        return states


def folded(state: dict) -> dict:
    """The checkpoint's state with the positional convolution's weight norm folded (`weight_g` x `weight_v` over the
    norm of all but the kernel's axis, as weight_norm's dim=2) and the masking embedding taken out."""
    state = dict(state)
    g = state.pop("encoder.pos_conv_embed.conv.weight_g")
    v = state.pop("encoder.pos_conv_embed.conv.weight_v")
    state["encoder.pos_conv_embed.conv.weight"] = g * v / v.norm(dim=(0, 1), keepdim=True)
    state.pop("masked_spec_embed", None)
    return state


def resample_kernel(orig: int, new: int, width: int = 6, rolloff: float = 0.99):
    """torchaudio's `_get_sinc_resample_kernel` (sinc_interp_hann): [new, 1, taps] and the padding it reads with."""
    g = math.gcd(orig, new)
    orig, new = orig // g, new // g
    base = min(orig, new) * rolloff
    pad = math.ceil(width * orig / base)
    idx = torch.arange(-pad, pad + orig, dtype=torch.float64)[None, None] / orig
    t = (torch.arange(0, -new, -1, dtype=torch.float64)[:, None, None] / new + idx) * base
    t = t.clamp(-width, width)
    window = torch.cos(t * math.pi / width / 2) ** 2
    t = t * math.pi
    kernel = torch.where(t == 0, torch.tensor(1.0, dtype=torch.float64), torch.sin(t) / t) * window * (base / orig)
    return kernel.float(), pad, orig, new


class Ear:
    """StyleTTS 2's WavLMLoss: their audio and ours at 24 kHz, each heard at 16 kHz, the L1 of every hidden state
    summed. Their side needs no gradient; WavLM is held."""

    def __init__(self, model: WavLM, device, sr: int = 24000):
        self.model = model.to(device).eval()
        self.model.requires_grad_(False)
        kernel, self.pad, self.orig, self.new = resample_kernel(sr, 16000)
        self.kernel = kernel.to(device)

    def resample(self, y):
        """[B, samples] at the given rate to 16 kHz, as torchaudio's Resample."""
        n = y.shape[-1]
        x = F.pad(y[:, None], (self.pad, self.pad + self.orig))
        out = F.conv1d(x, self.kernel, stride=self.orig).transpose(1, 2).reshape(y.shape[0], -1)
        return out[:, : math.ceil(self.new * n / self.orig)]

    def __call__(self, y_hat, y):
        with torch.no_grad():
            real = self.model(self.resample(y))
        fake = self.model(self.resample(y_hat))
        return sum((r - f).abs().mean() for r, f in zip(real, fake))
