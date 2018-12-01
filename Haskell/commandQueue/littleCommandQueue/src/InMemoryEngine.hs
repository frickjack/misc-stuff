module InMemoryEngine
(
  InMemoryEngine
) where

import LittleCommandEngine

data InMemoryEngine = {
    
}

instance LittleCommandEngine InMemoryEngine where
    driver engine = driver' where