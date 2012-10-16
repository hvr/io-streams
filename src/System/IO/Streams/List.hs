-- | List conversions and utilities

module System.IO.Streams.List
 ( -- * List conversions
   fromList
 , toList
 , writeList
   -- * Utility
 , listOutputStream
 ) where

import Control.Concurrent.MVar    ( modifyMVar
                                  , modifyMVar_
                                  , newMVar
                                  )
import System.IO.Streams.Internal ( InputStream
                                  , OutputStream
                                  , Sink(..)
                                  , SP(..)
                                  , connect
                                  , nullSink
                                  , nullSource
                                  , sinkToStream
                                  , sourceToStream
                                  , withDefaultPushback
                                  , write
                                  )


------------------------------------------------------------------------------
-- | Transforms a list into an 'InputStream' that produces no side effects.
fromList :: [c] -> IO (InputStream c)
fromList = sourceToStream . f
  where
    f []     = withDefaultPushback $ return $! SP (nullSource) Nothing
    f (x:xs) = withDefaultPushback $ return $! SP (f xs) (Just x)
{-# INLINE fromList #-}


------------------------------------------------------------------------------
-- | 'listOutputStream' returns an 'OutputStream' which stores values fed into
-- it and an action which flushes all stored values to a list.
--
-- The flush action resets the store.
--
-- Note that this function /will/ buffer any input sent to it on the heap.
-- Please don't use this unless you're sure that the amount of input provided
-- is bounded and will fit in memory without issues.
listOutputStream :: IO (OutputStream c, IO [c])
listOutputStream = do
    r <- newMVar id
    c <- sinkToStream $ consumer r
    return (c, flush r)

  where
    consumer r = Sink $ maybe (return nullSink)
                              (\c -> do
                                   modifyMVar_ r $ \dl -> return (dl . (c:))
                                   return $ consumer r)

    flush r = modifyMVar r $ \dl -> return (id, dl [])
{-# INLINE listOutputStream #-}


------------------------------------------------------------------------------
-- | Drains an 'InputStream', converting it to a list.
toList :: InputStream a -> IO [a]
toList is = do
    (os, grab) <- listOutputStream
    connect is os >> grab
{-# INLINE toList #-}


------------------------------------------------------------------------------
-- | Feeds a list to an 'OutputStream'. Does /not/ write an end-of-stream to
-- the list.
writeList :: [a] -> OutputStream a -> IO ()
writeList xs os = mapM_ (flip write os . Just) xs
{-# INLINE writeList #-}


