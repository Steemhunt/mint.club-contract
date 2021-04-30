# Mint Club
Smart contracts for mint.club

## Gas Consumption
·---------------------------------|----------------------------|-------------|-----------------------------·
|       Solc version: 0.8.3       ·  Optimizer enabled: false  ·  Runs: 200  ·  Block limit: 10000000 gas  │
··································|····························|·············|······························
|  Methods                        ·               40 gwei/gas                ·       2741.86 usd/eth       │
··················|···············|··············|·············|·············|···············|··············
|  Contract       ·  Method       ·  Min         ·  Max        ·  Avg        ·  # calls      ·  usd (avg)  │
··················|···············|··············|·············|·············|···············|··············
|  MintClubBond   ·  buy          ·      185809  ·     198982  ·     193118  ·           24  ·      21.18  │
··················|···············|··············|·············|·············|···············|··············
|  MintClubBond   ·  createToken  ·           -  ·          -  ·     208829  ·           25  ·      22.90  │
··················|···············|··············|·············|·············|···············|··············
|  MintClubToken  ·  approve      ·       47204  ·      47216  ·      47215  ·           25  ·       5.18  │
··················|···············|··············|·············|·············|···············|··············
|  MintClubToken  ·  init         ·           -  ·          -  ·      91593  ·           25  ·      10.05  │
··················|···············|··············|·············|·············|···············|··············
|  MintClubToken  ·  mint         ·           -  ·          -  ·      71358  ·           25  ·       7.83  │
··················|···············|··············|·············|·············|···············|··············
|  Deployments                    ·                                          ·  % of limit   ·             │
··································|··············|·············|·············|···············|··············
|  MintClubBond                   ·     3685786  ·    3685810  ·    3685808  ·       36.9 %  ·     404.24  │
··································|··············|·············|·············|···············|··············
|  MintClubToken                  ·           -  ·          -  ·    1798381  ·         18 %  ·     197.24  │
·---------------------------------|--------------|-------------|-------------|---------------|-------------·