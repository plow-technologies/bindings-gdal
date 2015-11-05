{-# LANGUAGE CPP #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE StandaloneDeriving #-}

module GDAL.Internal.DataType (
    GDALType (..)
  , KnownDataType
  , DataType (..)
  , CDataTypeT
  , GType

  , dataType
  , dataTypeSize
  , dataTypeByName
  , dataTypeUnion
  , dataTypeIsComplex
) where

#include "gdal.h"
#include "bindings.h"

{#context lib = "gdal" prefix = "GDAL" #}

import Data.Int (Int8, Int16, Int32)
import Data.Complex (Complex(..), realPart)
import Data.Coerce (coerce)
import Data.Proxy (Proxy(..))
import Data.Word (Word8, Word16, Word32)
import qualified Data.Vector.Storable as St
import qualified Data.Vector.Storable.Mutable as Stm

import Foreign.C.Types
import Foreign.C.String (withCString)
import Foreign.Marshal.Utils (toBool)
import Foreign.Ptr (Ptr)
import Foreign.Storable (Storable(..))

import System.IO.Unsafe (unsafePerformIO)

import GDAL.Internal.Util (toEnumC, fromEnumC)



{#enum DataType {} omit (GDT_TypeCount) deriving (Eq, Show, Bounded) #}

{#fun pure unsafe GetDataTypeSize as dataTypeSize
    { fromEnumC `DataType' } -> `Int' #}

{#fun pure unsafe DataTypeIsComplex as ^
    { fromEnumC `DataType' } -> `Bool' #}

{#fun pure unsafe GetDataTypeByName as dataTypeByName
    { `String' } -> `DataType' toEnumC #}

{#fun pure unsafe DataTypeUnion as ^
    { fromEnumC `DataType', fromEnumC `DataType' } -> `DataType' toEnumC #}



------------------------------------------------------------------------------
-- GDALType
------------------------------------------------------------------------------
type CDataTypeT a = GType (DataTypeT a)

class (Eq a , Storable a , KnownDataType (DataTypeT a)) => GDALType a where
  type DataTypeT a :: DataType
  toGType    :: St.Vector    a              -> St.Vector    (CDataTypeT a)
  fromGType  :: St.Vector    (CDataTypeT a) -> St.Vector    a
  toGTypeM   :: St.MVector s a              -> St.MVector s (CDataTypeT a)
  fromGTypeM :: St.MVector s (CDataTypeT a) -> St.MVector s a

  toCDouble :: a -> CDouble
  fromCDouble :: CDouble -> a

type family GType (k :: DataType) where
  GType 'GDT_Byte     = CUChar
  GType 'GDT_UInt16   = CUShort
  GType 'GDT_UInt32   = CUInt
  GType 'GDT_Int16    = CShort
  GType 'GDT_Int32    = CInt
  GType 'GDT_Float32  = CFloat
  GType 'GDT_Float64  = CDouble
  GType 'GDT_CInt16   = CComplex CShort
  GType 'GDT_CInt32   = CComplex CInt
  GType 'GDT_CFloat32 = CComplex CFloat
  GType 'GDT_CFloat64 = CComplex CDouble

newtype CComplex a = CComplex (Complex a)
  deriving (Eq, Show)

class (Storable (GType k), Eq (GType k)) => KnownDataType (k :: DataType) where
  dataTypeVal :: Proxy (k :: DataType) -> DataType

dataType :: forall a. GDALType a => Proxy a -> DataType
dataType _ = dataTypeVal (Proxy :: Proxy (DataTypeT a))
{-# INLINE dataType #-}

instance KnownDataType 'GDT_Byte      where dataTypeVal _ = GDT_Byte
instance KnownDataType 'GDT_UInt16    where dataTypeVal _ = GDT_UInt16
instance KnownDataType 'GDT_UInt32    where dataTypeVal _ = GDT_UInt32
instance KnownDataType 'GDT_Int16     where dataTypeVal _ = GDT_Int16
instance KnownDataType 'GDT_Int32     where dataTypeVal _ = GDT_Int32
instance KnownDataType 'GDT_Float32   where dataTypeVal _ = GDT_Float32
instance KnownDataType 'GDT_Float64   where dataTypeVal _ = GDT_Float64
#ifdef STORABLE_COMPLEX
instance KnownDataType 'GDT_CInt16    where dataTypeVal _ = GDT_CInt16
instance KnownDataType 'GDT_CInt32    where dataTypeVal _ = GDT_CInt32
instance KnownDataType 'GDT_CFloat32  where dataTypeVal _ = GDT_CFloat32
instance KnownDataType 'GDT_CFloat64  where dataTypeVal _ = GDT_CFloat64
#endif


instance GDALType Word8 where
  type DataTypeT Word8 = 'GDT_Byte
  toCDouble = fromIntegral
  fromCDouble = truncate
  toGType    = coerce
  fromGType  = coerce
  toGTypeM   = coerce
  fromGTypeM = coerce
  {-# INLINE toGTypeM #-}
  {-# INLINE fromGTypeM #-}
  {-# INLINE toGType #-}
  {-# INLINE fromGType #-}
  {-# INLINE toCDouble #-}
  {-# INLINE fromCDouble #-}

instance GDALType Word16 where
  type DataTypeT Word16 = 'GDT_UInt16
  toCDouble = fromIntegral
  fromCDouble = truncate
  toGType    = coerce
  fromGType  = coerce
  toGTypeM   = coerce
  fromGTypeM = coerce
  {-# INLINE toGTypeM #-}
  {-# INLINE fromGTypeM #-}
  {-# INLINE toGType #-}
  {-# INLINE fromGType #-}
  {-# INLINE toCDouble #-}
  {-# INLINE fromCDouble #-}

instance GDALType Word32 where
  type DataTypeT Word32 = 'GDT_UInt32
  toCDouble = fromIntegral
  fromCDouble = truncate
  toGType    = coerce
  fromGType  = coerce
  toGTypeM   = coerce
  fromGTypeM = coerce
  {-# INLINE toGTypeM #-}
  {-# INLINE fromGTypeM #-}
  {-# INLINE toGType #-}
  {-# INLINE fromGType #-}
  {-# INLINE toCDouble #-}
  {-# INLINE fromCDouble #-}

instance GDALType Int8 where
  type DataTypeT Int8 = 'GDT_Byte
  toCDouble = fromIntegral
  fromCDouble = truncate
  toGType    = St.unsafeCast
  fromGType  = St.unsafeCast
  toGTypeM   = Stm.unsafeCast
  fromGTypeM = Stm.unsafeCast
  {-# INLINE toGTypeM #-}
  {-# INLINE fromGTypeM #-}
  {-# INLINE toGType #-}
  {-# INLINE fromGType #-}
  {-# INLINE toCDouble #-}
  {-# INLINE fromCDouble #-}

instance GDALType Int16 where
  type DataTypeT Int16 = 'GDT_Int16
  toCDouble = fromIntegral
  fromCDouble = truncate
  toGType    = coerce
  fromGType  = coerce
  toGTypeM   = coerce
  fromGTypeM = coerce
  {-# INLINE toGTypeM #-}
  {-# INLINE fromGTypeM #-}
  {-# INLINE toGType #-}
  {-# INLINE fromGType #-}
  {-# INLINE toCDouble #-}
  {-# INLINE fromCDouble #-}

instance GDALType Int32 where
  type DataTypeT Int32 = 'GDT_Int32
  toCDouble = fromIntegral
  fromCDouble = truncate
  toGType    = coerce
  fromGType  = coerce
  toGTypeM   = coerce
  fromGTypeM = coerce
  {-# INLINE toGTypeM #-}
  {-# INLINE fromGTypeM #-}
  {-# INLINE toGType #-}
  {-# INLINE fromGType #-}
  {-# INLINE toCDouble #-}
  {-# INLINE fromCDouble #-}

instance GDALType Float where
  type DataTypeT Float = 'GDT_Float32
  fromCDouble = realToFrac
  toCDouble = realToFrac
  toGType    = coerce
  fromGType  = coerce
  toGTypeM   = coerce
  fromGTypeM = coerce
  {-# INLINE toGTypeM #-}
  {-# INLINE fromGTypeM #-}
  {-# INLINE toGType #-}
  {-# INLINE fromGType #-}
  {-# INLINE toCDouble #-}
  {-# INLINE fromCDouble #-}

instance GDALType Double where
  type DataTypeT Double = 'GDT_Float64
  toCDouble = realToFrac
  fromCDouble = realToFrac
  toGType    = coerce
  fromGType  = coerce
  toGTypeM   = coerce
  fromGTypeM = coerce
  {-# INLINE toGTypeM #-}
  {-# INLINE fromGTypeM #-}
  {-# INLINE toGType #-}
  {-# INLINE fromGType #-}
  {-# INLINE toCDouble #-}
  {-# INLINE fromCDouble #-}

#ifdef STORABLE_COMPLEX

deriving instance Storable a => Storable (CComplex a)

instance GDALType (Complex Int16) where
  type DataTypeT (Complex Int16) = 'GDT_CInt16
  toCDouble = fromIntegral . realPart
  fromCDouble d = fromCDouble d :+ fromCDouble d
  toGType    = coerce
  fromGType  = coerce
  toGTypeM   = coerce
  fromGTypeM = coerce
  {-# INLINE toGTypeM #-}
  {-# INLINE fromGTypeM #-}
  {-# INLINE toGType #-}
  {-# INLINE fromGType #-}
  {-# INLINE toCDouble #-}
  {-# INLINE fromCDouble #-}

instance GDALType (Complex Int32) where
  type DataTypeT (Complex Int32) = 'GDT_CInt32
  toCDouble = fromIntegral . realPart
  fromCDouble d = fromCDouble d :+ fromCDouble d
  toGType    = coerce
  fromGType  = coerce
  toGTypeM   = coerce
  fromGTypeM = coerce
  {-# INLINE toGTypeM #-}
  {-# INLINE fromGTypeM #-}
  {-# INLINE toGType #-}
  {-# INLINE fromGType #-}
  {-# INLINE toCDouble #-}
  {-# INLINE fromCDouble #-}

instance GDALType (Complex Float) where
  type DataTypeT (Complex Float) = 'GDT_CFloat32
  toCDouble = realToFrac . realPart
  fromCDouble d = fromCDouble d :+ fromCDouble d
  toGType    = coerce
  fromGType  = coerce
  toGTypeM   = coerce
  fromGTypeM = coerce
  {-# INLINE toGTypeM #-}
  {-# INLINE fromGTypeM #-}
  {-# INLINE toGType #-}
  {-# INLINE fromGType #-}
  {-# INLINE toCDouble #-}
  {-# INLINE fromCDouble #-}

instance GDALType (Complex Double) where
  type DataTypeT (Complex Double) = 'GDT_CFloat64
  toCDouble = realToFrac . realPart
  fromCDouble d = fromCDouble d :+ fromCDouble d
  toGType    = coerce
  fromGType  = coerce
  toGTypeM   = coerce
  fromGTypeM = coerce
  {-# INLINE toGTypeM #-}
  {-# INLINE fromGTypeM #-}
  {-# INLINE toGType #-}
  {-# INLINE fromGType #-}
  {-# INLINE toCDouble #-}
  {-# INLINE fromCDouble #-}
#endif