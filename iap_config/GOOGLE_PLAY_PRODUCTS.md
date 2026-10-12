# Google Play IAP — ShiftLens

Package: `com.ShiftLensMNG.ShiftLens`

Remote config: `https://api2.blwsmartware.net/R252.json`  
If JSON field `disable` is `1`, hide Google Play purchase popups. Shop stays open for coin unlocks.

## Consumable coin packs (buy many times)

| Product ID | Coins |
| --- | --- |
| `sl_pack_1` | 50 |
| `sl_pack_2` | 100 |
| `sl_pack_3` | 200 |
| `sl_pack_4` | 350 |
| `sl_pack_5` | 500 |
| `sl_pack_6` | 750 |
| `sl_pack_7` | 1000 |
| `sl_pack_8` | 1500 |
| `sl_pack_9` | 2200 |
| `sl_pack_10` | 3000 |

## One-time

| Product ID | Unlock |
| --- | --- |
| `sl_remove_ads` | Hide the banner |
| `sl_pro` | More than 8 schedules |

Create these IDs in Play Console → Monetize → In-app products. Coin packs must be **consumable**. Remove ads and Pro must be **non-consumable**.
