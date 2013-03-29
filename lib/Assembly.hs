
module Assembly (Assembly(..), assemble, nothing, here, unit, units, pad_assembly, return_assembly, fail_assembly, append_assembly, bind_assembly, set_counter, enforce_counter) where

import Data.Monoid
import qualified Data.Foldable as F
import Control.Monad.Fix
import Text.Printf

newtype Assembly mon ctr a = Assembly (ctr -> (mon, ctr, a))

assemble :: Num ctr => Assembly mon ctr a -> mon
assemble (Assembly f) = comp where (comp, _, _) = f 0

nothing :: Monoid mon => Assembly mon ctr ()
nothing = Assembly (\c -> (mempty, c, ()))

here :: Monoid mon => Assembly mon ctr ctr
here = Assembly (\c -> (mempty, c, c))

unit :: Num ctr => mon -> Assembly mon ctr ()
unit u = Assembly (\c -> (u, c + 1, ()))

units :: (Monoid mon, Num ctr, F.Foldable a) => a mon -> Assembly mon ctr ()
units us = Assembly (\c -> (F.fold us, F.foldl (const . (+ 1)) c us, ()))

pad_assembly :: (Monoid mon, Integral ctr) => ctr -> mon -> Assembly mon ctr a -> Assembly mon ctr a
pad_assembly size filling (Assembly code) = Assembly f where
    f start = let
        (coderes, finish, ret) = code start
        res = if finish > start + size
            then error$ printf "Code given to pad_assembly was larger than the alloted size (0x%x - 0x%x > 0x%x)"
                               (toInteger finish) (toInteger start) (toInteger size)
            else coderes <> F.fold (replicate (fromIntegral (start + size - finish)) filling)
        in (res, start + size, ret)

return_assembly :: Monoid mon => a -> Assembly mon ctr a
return_assembly x = Assembly (\c -> (mempty, c, x))

fail_assembly :: Integral ctr => String -> Assembly mon ctr a
fail_assembly mess = Assembly f where
    f start = let
        err = error$ printf "%s at 0x%x" mess (toInteger start)
        in (err, start, err)  -- Don't be strict.

append_assembly :: Monoid mon => Assembly mon ctr a -> Assembly mon ctr b -> Assembly mon ctr b
append_assembly (Assembly left) (Assembly right) = Assembly f where
    f start = let
        (leftres, mid, _) = left start
        (rightres, end, ret) = right mid
        in (leftres <> rightres, end, ret)

bind_assembly :: Monoid mon => Assembly mon ctr a -> (a -> Assembly mon ctr b) -> Assembly mon ctr b
bind_assembly (Assembly left) rightf = Assembly f where
    f start = let
        (leftres, mid, inter) = left start
        Assembly right = rightf inter
        (rightres, end, ret) = right mid
        in (leftres <> rightres, end, ret)

fix_assembly :: (a -> Assembly mon ctr a) -> Assembly mon ctr a
fix_assembly f = Assembly g where
    g start = let
        Assembly fixed = f ret
        (res, end, ret) = fixed start
        in (res, end, ret)

set_counter :: (Monoid mon) => ctr -> Assembly mon ctr ()
set_counter new = Assembly (\_ -> (mempty, new, ()))

enforce_counter :: (Monoid mon, Integral ctr) => ctr -> Assembly mon ctr ()
enforce_counter expected = Assembly f where
    f got = let
        res = if got == expected
            then mempty
            else error$ printf "Something was misaligned (0x%x /= 0x%x)" (toInteger got) (toInteger expected)
        in (res, expected, ())

instance (Monoid mon, Integral ctr) => Monad (Assembly mon ctr) where
    return = return_assembly
    (>>=) = bind_assembly
    (>>) = append_assembly
    fail = fail_assembly

instance (Monoid mon, Integral ctr) => MonadFix (Assembly mon ctr) where
    mfix = fix_assembly
