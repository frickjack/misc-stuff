module LittleCommandQueue 
(
    LittleCommand,
    URI,
    LittleContext,
    LittleHandle,
    TimeMessage,
    LittleResult
) where

type URI = String



data LittleCommand = LittleCommand {
    uri :: URI,
    args :: String,
    subcommands :: [LittleCommand]
} deriving (Show);


data TimeMessage a = TMess {
    timestamp :: Int,
    message   :: a
}

data LittleContext a = LittleContext {
    subject :: URI,
    body :: TimeMessage a
}

ctxPayload :: LittleContext a -> a
ctxPayload ctx = message $ body ctx

ctxTimestamp :: LittleContext a -> Int
ctxTimestamp ctx = timestamp $ body ctx

type LittleHandle = TimeMessage String
handle :: LittleHandle -> String
handle x = message x

data LittleResult = LittleProgress {
    progressSummary :: Int,
    recentHistory :: [TimeMessage String]
} | LittleSuccess {
    result :: String
} | LittleFail {
    errorCode :: Int,
    errorMessage :: String
}

