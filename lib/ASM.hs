
{-# LANGUAGE RecursiveDo #-}

module ASM (
    ASM,
    byte, bytes, ascii, bytestring, binfile, fill, pad, hex, hexdata,
    le16, be16, le32, be32, le64, be64, lefloat, befloat, ledouble, bedouble,
    nothing, here, set_counter,
    assemble_asm, no_overflow,
    startof, endof, sizeof,
    rep, repfor, skip, (>>.)
) where

import Data.Word
import Data.Bits
import Data.Char
import qualified Data.Sequence as S
import qualified Data.Foldable as F
import qualified Data.ByteString as B
import Assembly
import Unsafe.Coerce  -- for serializing floats and doubles
import System.IO.Unsafe  -- for binfile

type ASM ctr a = Assembly (S.Seq Word8) ctr a

assemble_asm :: Num ctr => ASM ctr a -> B.ByteString
assemble_asm = B.pack . F.toList . assemble

byte :: Enum ctr => Word8 -> ASM ctr ()
byte = unit . S.singleton

bytes :: Enum ctr => F.Foldable t => t Word8 -> ASM ctr ()
bytes bs = Assembly (\c -> (S.fromList (F.toList bs), F.foldl (const . succ) c bs, ()))

ascii :: Enum ctr => [Char] -> ASM ctr ()
ascii = bytes . map (fromIntegral . ord)

bytestring :: Enum ctr => B.ByteString -> ASM ctr ()
bytestring = bytes . B.unpack

{-# NOINLINE binfile #-}
binfile :: Enum ctr => String -> ASM ctr ()
binfile = bytestring . unsafePerformIO . B.readFile

fill :: Integral ctr => ctr -> Word8 -> ASM ctr ()
fill size b = if size >= 0
    then Assembly (\c -> (S.replicate (fromIntegral size) b, c + size, ()))
    else error$ "Tried to fill a block with negative size (did something assemble too large?)"

pad :: Integral ctr => ctr -> Word8 -> ASM ctr a -> ASM ctr a
pad size = pad_assembly size . S.singleton

hex :: String -> [Word8]
hex [] = []
hex (c:rest) | not (isHexDigit c) = hex rest
hex (h:l:rest) | isHexDigit l = fromIntegral (digitToInt h * 16 + digitToInt l) : hex rest
hex _ = error "Odd number of hex digits in hexdata string."

hexdata :: Enum ctr => String -> ASM ctr ()
hexdata = bytes . hex

le16 :: (Enum ctr, Show ctr) => Word16 -> ASM ctr ()
le16 w = do
    byte$ fromIntegral w
    byte$ fromIntegral (shiftR w 8)
be16 :: (Enum ctr, Show ctr) => Word16 -> ASM ctr ()
be16 w = do
    byte$ fromIntegral (shiftR w 8)
    byte$ fromIntegral w
le32 :: (Enum ctr, Show ctr) => Word32 -> ASM ctr ()
le32 w = do
    byte$ fromIntegral w
    byte$ fromIntegral (shiftR w 8)
    byte$ fromIntegral (shiftR w 16)
    byte$ fromIntegral (shiftR w 24)
be32 :: (Enum ctr, Show ctr) => Word32 -> ASM ctr ()
be32 w = do
    byte$ fromIntegral (shiftR w 24)
    byte$ fromIntegral (shiftR w 16)
    byte$ fromIntegral (shiftR w 8)
    byte$ fromIntegral w
le64 :: (Enum ctr, Show ctr) => Word64 -> ASM ctr ()
le64 w = do
    byte$ fromIntegral w
    byte$ fromIntegral (shiftR w 8)
    byte$ fromIntegral (shiftR w 16)
    byte$ fromIntegral (shiftR w 24)
    byte$ fromIntegral (shiftR w 32)
    byte$ fromIntegral (shiftR w 40)
    byte$ fromIntegral (shiftR w 48)
    byte$ fromIntegral (shiftR w 56)
be64 :: (Enum ctr, Show ctr) => Word64 -> ASM ctr ()
be64 w = do
    byte$ fromIntegral (shiftR w 56)
    byte$ fromIntegral (shiftR w 48)
    byte$ fromIntegral (shiftR w 40)
    byte$ fromIntegral (shiftR w 32)
    byte$ fromIntegral (shiftR w 24)
    byte$ fromIntegral (shiftR w 16)
    byte$ fromIntegral (shiftR w 8)
    byte$ fromIntegral w
lefloat :: (Enum ctr, Show ctr) => Float -> ASM ctr ()
lefloat = le32 . unsafeCoerce
befloat :: (Enum ctr, Show ctr) => Float -> ASM ctr ()
befloat = be32 . unsafeCoerce
ledouble :: (Enum ctr, Show ctr) => Double -> ASM ctr ()
ledouble = le32 . unsafeCoerce
bedouble :: (Enum ctr, Show ctr) => Double -> ASM ctr ()
bedouble = be32 . unsafeCoerce


no_overflow' :: (Integral a, Integral b) => b -> b -> a -> Maybe b
no_overflow' min max x = let
    in if toInteger min <= toInteger x && toInteger x <= toInteger max
        then Just (fromIntegral x)
        else Nothing

no_overflow :: (Integral a, Integral b, Bounded b) => a -> Maybe b
no_overflow = no_overflow' minBound maxBound


startof x = do
    start <- here
    x
    return start

endof x = x >> here

sizeof x = do
    start <- here
    x
    end <- here
    return (end - start)

rep :: Show ctr => (ctr -> ASM ctr ()) -> ASM ctr a -> ASM ctr a
rep branch code = mdo
    start <- here
    res <- code
    branch start
    return res

repfor :: Show ctr => ASM ctr () -> (ctr -> ASM ctr ()) -> ASM ctr a -> ASM ctr a
repfor init branch code = mdo
    init
    start <- here
    res <- code
    branch start
    return res

skip :: Show ctr => (ctr -> ASM ctr ()) -> ASM ctr a -> ASM ctr a
skip branch code = mdo
    branch end
    res <- code
    end <- here
    return res

infixl 1 >>. 
cmp >>. branch = (cmp >>) . branch
