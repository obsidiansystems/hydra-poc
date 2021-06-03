{-# LANGUAGE TypeApplications #-}

module Main where

import Cardano.Prelude hiding (Option, option)

import Control.Concurrent.STM (newBroadcastTChanIO, writeTChan)
import Hydra.API.Server (runAPIServer)
import Hydra.Chain.ZeroMQ (createMockChainClient)
import qualified Hydra.Ledger.Mock as Ledger
import Hydra.Logging
import Hydra.Logging.Messages (HydraLog (..))
import Hydra.Logging.Monitoring (withMonitoring)
import Hydra.Logic (
  Environment (..),
  Event (..),
  HeadParameters (..),
  SnapshotStrategy (..),
  createHeadState,
 )
import Hydra.Network.Ouroboros (withOuroborosHydraNetwork)
import Hydra.Node (
  EventQueue (..),
  HydraNode (..),
  createEventQueue,
  createHydraHead,
  runHydraNode,
 )
import Hydra.Node.Version (gitRevision, showFullVersion, version)
import Hydra.Option (Option (..), parseHydraOptions)

main :: IO ()
main =
  identifyNode <$> parseHydraOptions >>= \case
    option
      | displayVersion option == True -> putStr (showFullVersion version gitRevision)
      | otherwise -> startHydraNode option

startHydraNode :: Option -> IO ()
startHydraNode Option{nodeId, verbosity, host, port, peers, apiHost, apiPort, monitoringPort} =
  withTracer verbosity show $ \tracer' ->
    withMonitoring monitoringPort tracer' $ \tracer -> do
      let env = Environment nodeId
      eq <- createEventQueue
      let headState = createHeadState [] (HeadParameters 3) SnapshotStrategy
      hh <- createHydraHead headState Ledger.mockLedger
      oc <- createMockChainClient eq (contramap MockChain tracer)
      withOuroborosHydraNetwork (show host, port) peers (putEvent eq . NetworkEvent) $ \hn -> do
        responseChannel <- newBroadcastTChanIO
        let sendResponse = atomically . writeTChan responseChannel
        let node = HydraNode{eq, hn, hh, oc, sendResponse, env}
        race_
          (runAPIServer apiHost apiPort responseChannel node (contramap APIServer tracer))
          (runHydraNode (contramap Node tracer) node)

identifyNode :: Option -> Option
identifyNode opt@Option{verbosity = Verbose "HydraNode", nodeId} = opt{verbosity = Verbose $ "HydraNode-" <> show nodeId}
identifyNode opt = opt
