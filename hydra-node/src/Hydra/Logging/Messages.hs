{-# LANGUAGE UndecidableInstances #-}

-- | Aggregates all tracing messages in a single type.
--
-- This module provides a central point where top-level traced messages are
-- grouped. This is useful for traces consumers that will need to do something
-- specific depending on various tracing messages, eg. monitoring and metrics
-- collection.
module Hydra.Logging.Messages where

import Hydra.Prelude

import Hydra.API.Server (APIServerLog)
import Hydra.Chain.Direct.Handlers (DirectChainLog)
import Hydra.Ledger (IsTx)
import Hydra.Node (HydraNodeLog)

data HydraLog tx net
  = DirectChain {directChain :: DirectChainLog}
  | APIServer {api :: APIServerLog}
  | Network {network :: net}
  | Node {node :: HydraNodeLog tx}
  deriving stock (Eq, Show, Generic)
  deriving anyclass (ToJSON)

instance
  ( Arbitrary net
  , Arbitrary DirectChainLog
  , Arbitrary APIServerLog
  , IsTx tx
  ) =>
  Arbitrary (HydraLog tx net)
  where
  arbitrary = genericArbitrary
