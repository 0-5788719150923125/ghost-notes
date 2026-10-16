import Mathlib

/-! The workbench's own check, built once after an install: Mathlib imports, and a theorem
from it elaborates. If this file builds, a proof can be checked. -/

theorem ghost_workbench_check : Irrational (Real.sqrt 2) := irrational_sqrt_two
