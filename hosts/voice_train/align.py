"""align.py - VITS's monotonic alignment search, compiled by numba (train.py puts it where Piper looks).

Piper's trainer finds, for each utterance, the most likely path of its phonemes through its frames with
a small Cython module that its wheel ships unbuilt (`piper/train/vits/monotonic_align/core.pyx` is not in
it, and building it wants a C compiler). This is the same search line for line - `_each` is VITS's
`maximum_path_each`, `maximum_path_c` its batch over the utterances - on numba, which librosa already
brings, so nothing is compiled by hand. test_train.py holds it to the reference, path for path.

    paths   int32 [b, t_y, t_x], zeros: the path is written as ones
    values  float32 [b, t_y, t_x]: the log-likelihoods, summed in place along the best path
    t_ys    int32 [b]: each utterance's frames; t_xs its phonemes
"""

import numba
import numpy as np


@numba.njit(cache=True)
def _each(path, value, t_y, t_x):
    neg = np.float32(-1e9)
    for y in range(t_y):
        for x in range(max(0, t_x + y - t_y), min(t_x, y + 1)):
            cur = neg if x == y else value[y - 1, x]
            if x == 0:
                prev = np.float32(0.0) if y == 0 else neg
            else:
                prev = value[y - 1, x - 1]
            value[y, x] += max(prev, cur)
    index = t_x - 1
    for y in range(t_y - 1, -1, -1):
        path[y, index] = 1
        if index != 0 and (index == y or value[y - 1, index] < value[y - 1, index - 1]):
            index -= 1


@numba.njit(parallel=True, cache=True)
def maximum_path_c(paths, values, t_ys, t_xs):
    for i in numba.prange(paths.shape[0]):
        _each(paths[i], values[i], t_ys[i], t_xs[i])
