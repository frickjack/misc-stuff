module LittleCommandEngine
(
  LittleEngine
) where

import LittleCommandQueue


--
-- Submit a command to a run queue,
-- and query for the command's execution status
--
class LittleDriver driver where
    submitCommand :: driver -> LittleContext LittleCommand -> IO LittleHandle
    checkProgress :: driver -> LittleContext LittleHandle -> IO LittleResult

type LittleProgress = (Int, [String])

class LittleFeedback fb where
    push :: fb -> LittleProgress -> IO()    

--
-- Execute some command 
--
class LittleRunner runner where
    executeCommand :: runner -> LittleContext LittleCommand -> (LittleProgress -> IO()) -> IO String
    uri :: runner -> URI

class LittleEngine eng where
    driver :: LittleDriver dr => eng -> dr
    lookupRunner :: LittleRunner runner => eng -> URI -> Maybe runner
    registerRunner :: LittleRunner runner => eng -> URI -> runner -> eng
