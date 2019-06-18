module Main where
import LittleCommandQueue
import LittleCommandEngine

-- Don't forget - multiline in ghci:
-- :{ ... :}


whatever =
    let x=0
        y=1
    in x+y 


main :: IO()
main = putStrLn "hello"
