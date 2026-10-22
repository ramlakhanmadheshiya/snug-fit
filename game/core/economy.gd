class_name Economy
extends RefCounted
## Every coin amount, price and daily allowance in one place.

const START_COINS: int = 150
## First clear of a level.
const LEVEL_REWARD: int = 5
## Paid for each star earned for the first time (so improving 1★ -> 3★ pays 10 more).
const STAR_REWARD: int = 5
## Clearing every level of a chapter.
const CHAPTER_BONUS: int = 100

## A hint outlines where the next piece goes.
const HINT_COST: int = 30
## Free hints each day (Supporters get more).
const FREE_HINTS: int = 1
const SUPPORTER_FREE_HINTS: int = 3
## "Free coins" videos in the shop.
const VIDEO_COINS: int = 25
const VIDEO_COINS_PER_DAY: int = 5
## Level keys from videos.
const VIDEO_KEYS_PER_DAY: int = 5
## Chapter keys (open a whole locked chapter) from videos.
const VIDEO_CHAPTER_KEYS_PER_DAY: int = 1
## A full-screen video after this many finished levels (never for Supporters).
const LEVELS_PER_VIDEO: int = 5


## Coins for clearing a level: first clear, plus every star earned for the first time.
static func level_reward(first_clear: bool, new_stars: int) -> int:
	return (LEVEL_REWARD if first_clear else 0) + STAR_REWARD * maxi(0, new_stars)
