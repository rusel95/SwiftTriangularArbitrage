# Triangular Arbitraging at Binance written on Apple's Swift Language

Demo at telegram-bot:
https://t.me/SwiftTriangularArbitrageBot

## Has next modes:
    * standart_triangular_arbitraging - watching on current classic triangular arbitraging opportinitites on Binance
    * stable_triangular_arbitraging - watching on Triangles, where Start/End is some of the Stable coins.
    * start_alerting - mode for alerting about extra opportunities (when profit is exeptable)

# Steps:

## STEP 0: Gather correct list of tradeable coins
    Currently gathering only from Binance

## STEP 1: Structuring Triangular Pairs
    Finding the pairs for calculations
    - Get Pair A
    - Get Pair B
    - Get Pair C
    
## STEP 2: Calculate Surface Rate for all Triangulars (aproximately 2000 triangulars for Binance)
    
## STEP 3: Calculate Real Rate for our custom Amount of coin using Orders Book (Not implemented yet)
    
