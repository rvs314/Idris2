module Control.Monad.Maybe

-------------------------------------------------
-- The monad transformer `MaybeT m a` equips a monad with the ability to
-- return no value at all.

-- Sequenced actions of `MaybeT m a` produce a value `a` only if all of the
-- actions in the sequence returned a value.

-- This is isomorphic to `EitherT ()` and therefore less powerful than `EitherT e a`
-- ability to not return a result.
-------------------------------------------------

import Control.Monad.Trans
import Control.Monad.Reader
import Control.Monad.State
import Data.Maybe

public export
data MaybeT : (m : Type -> Type) -> (a : Type) -> Type where
  MkMaybeT : (1 _ : m (Maybe a)) -> MaybeT m a

export
%inline
runMaybeT : MaybeT m a -> m (Maybe a)
runMaybeT (MkMaybeT x) = x

export
%inline
isNothingT : Functor m => MaybeT m a -> m Bool
isNothingT = map isNothing . runMaybeT

export
%inline
isJustT : Functor m => MaybeT m a -> m Bool
isJustT = map isJust . runMaybeT

export
%inline
maybeT : Monad m => m b -> (a -> m b) -> MaybeT m a -> m b
maybeT v g x = runMaybeT x >>= maybe v g

export
%inline
fromMaybeT : Monad m => m a -> MaybeT m a -> m a
fromMaybeT v x = runMaybeT x >>= maybe v pure

export
%inline
toMaybeT : Functor m => Bool -> m a -> MaybeT m a
toMaybeT b m = MkMaybeT $ map (\a => toMaybe b a) m

||| map the underlying computation
||| The basic 'unwrap, apply, rewrap' of this transformer.
export
%inline
mapMaybeT : (m (Maybe a) -> n (Maybe a')) -> MaybeT m a -> MaybeT n a'
mapMaybeT f = MkMaybeT . f . runMaybeT

||| Analogous to Just, aka pure for MaybeT
export
%inline
just : Applicative m => a -> MaybeT m a
just = MkMaybeT . pure . Just

||| Analogous to Nothing, aka empty for MaybeT
export
%inline
nothing : Applicative m => MaybeT m a
nothing = MkMaybeT $ pure Nothing

-------------------------------------------------
-- Interface Implementations
-------------------------------------------------

on : (b -> b -> c) -> (a -> b) -> a -> a -> c
on f g x y = g x `f` g y

public export
Eq (m (Maybe a)) => Eq (MaybeT m a) where
 (==) = (==) `on` runMaybeT

public export
Ord (m (Maybe a)) => Ord (MaybeT m a) where
 compare = compare `on` runMaybeT

public export
Show (m (Maybe a)) => Show (MaybeT m a) where
  showPrec d (MkMaybeT x) = showCon d "MkMaybeT" $ showArg x

-- Corresponds to the Semigroup instance of Maybe
--
-- Note: This could also be implemented with only an Applicative
-- prerequisite: MkMaybeT x <+> MkMaybeT y = MkMaybeT $ [| x <+> y |]
--
-- However, the monadic version only runs the second argument
-- if the first fails, whish seems to be more efficient.
public export
Monad m => Semigroup (MaybeT m a) where
  MkMaybeT x <+> MkMaybeT y = MkMaybeT $ [| x <+> y |]

public export
Monad m => Monoid (MaybeT m a) where
  neutral = nothing

public export
Functor m => Functor (MaybeT m) where
  map f m = MkMaybeT $ map f <$> runMaybeT m

public export
Foldable m => Foldable (MaybeT m) where
  foldr f acc (MkMaybeT e)
    = foldr (\x,xs => maybe acc (`f` xs) x) acc e

  null (MkMaybeT e) = null e

public export
Traversable m => Traversable (MaybeT m) where
  traverse f (MkMaybeT x)
    = MkMaybeT <$> traverse (maybe (pure Nothing) (map Just . f)) x

public export
Applicative m => Applicative (MaybeT m) where
  pure = just
  MkMaybeT f <*> MkMaybeT x = MkMaybeT [| f <*> x |]

public export
Monad m => Monad (MaybeT m) where
  MkMaybeT x >>= k = MkMaybeT $ x >>= maybe (pure Nothing) (runMaybeT . k)

-- See note about Monad prerequisite on Semigroup instance.
public export
Monad m => Alternative (MaybeT m) where
  empty = nothing
  (<|>) = (<+>)

public export
MonadTrans MaybeT where
  lift = MkMaybeT . map Just

public export
HasIO m => HasIO (MaybeT m) where
  liftIO act = MkMaybeT $ liftIO (io_bind act (pure . Just))

public export
MonadReader r m => MonadReader r (MaybeT m) where
  ask = lift ask
  local f (MkMaybeT x) = MkMaybeT (local f x)

public export
MonadState s m => MonadState s (MaybeT m) where
  get = lift get
  put = lift . put

