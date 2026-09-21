/**
 * 연못에서 올라오는 것들 — 진짜 물고기, 밈 물고기, 잡동사니. 260+.
 * 한 줄: [key, name, rarity, glyph, zones, line?]
 *   rarity  c 흔함 · u 드묾 · r 희귀 · l 전설
 *   glyph   그리는 모양(캔버스 낙서) — fish 계열은 크기·색이 key 로 정해진다
 *   zones   어디서 나오나: d dock · r reeds · p pipe · e deep · i ice · * 어디서나
 * 이름은 카드에 그대로 찍힌다 — 문장으로 읽혀야 한다("you caught …" 뒤에 붙는다).
 */
export type R = 'c' | 'u' | 'r' | 'l';
export type G = 'fish' | 'flat' | 'long' | 'big' | 'boot' | 'can' | 'weed' | 'fax' | 'paper' | 'cat' | 'brick' | 'tape' | 'reel' | 'meme' | 'person' | 'ghost' | 'moon' | 'pigeon' | 'horse' | 'mirror' | 'phone' | 'frog' | 'crab' | 'duck' | 'bottle' | 'key' | 'ring' | 'shoe' | 'bag' | 'box' | 'chair' | 'bike' | 'shark' | 'octo' | 'jelly' | 'turtle' | 'snake' | 'bone' | 'coin' | 'hat' | 'sock' | 'log';
export type Row = readonly [string, string, R, G, string, string?];

export const ITEMS: readonly Row[] = [
  // ── 진짜 물고기 (연못·강·호수에 있을 법한 것 + 있어선 안 되는 것) ──
  ['carp', 'a carp', 'c', 'fish', 'dr'], ['carp2', 'a bigger carp', 'c', 'big', 'd'], ['koi', 'a koi that escaped someone\'s garden', 'u', 'fish', 'd'],
  ['bass', 'a largemouth bass', 'c', 'fish', 'dr'], ['bass2', 'a smallmouth bass', 'c', 'fish', 'dr'], ['bass3', 'a bass with a mouth of average size', 'u', 'fish', 'd'],
  ['catfish', 'a catfish', 'c', 'long', 'dp'], ['catfish2', 'a catfish the size of a child', 'r', 'big', 'e'], ['trout', 'a rainbow trout', 'c', 'fish', 'd'],
  ['trout2', 'a brown trout', 'c', 'fish', 'd'], ['trout3', 'a trout, but grey', 'c', 'fish', 'di'], ['perch', 'a perch', 'c', 'fish', 'dr'], ['pike', 'a pike', 'u', 'long', 'e'],
  ['pike2', 'a pike that has seen things', 'r', 'long', 'e'], ['eel', 'an eel', 'u', 'long', 'pe'], ['eel2', 'an electric eel (do not)', 'r', 'long', 'p'],
  ['bluegill', 'a bluegill', 'c', 'fish', 'dr'], ['crappie', 'a crappie', 'c', 'fish', 'dr'], ['crappie2', 'a crappie (it is fine, actually)', 'u', 'fish', 'd'],
  ['tilapia', 'a tilapia', 'c', 'fish', 'd'], ['salmon', 'a salmon that is very lost', 'u', 'fish', 'e'], ['tuna', 'a tuna. in a pond.', 'r', 'big', 'e'],
  ['goldfish', 'a goldfish', 'c', 'fish', 'dr'], ['goldfish2', 'a goldfish named Kevin', 'u', 'fish', 'r', 'the tag says so'], ['minnow', 'a minnow', 'c', 'fish', '*'],
  ['minnow2', 'seven minnows holding hands', 'u', 'fish', 'r'], ['sturgeon', 'a sturgeon', 'r', 'big', 'e'], ['sturgeon2', 'a sturgeon older than your country', 'l', 'big', 'e'],
  ['walleye', 'a walleye', 'c', 'fish', 'd'], ['zander', 'a zander', 'u', 'fish', 'e'], ['bream', 'a bream', 'c', 'flat', 'dr'], ['roach', 'a roach (the fish)', 'c', 'fish', 'dr'],
  ['roach2', 'a roach (not the fish)', 'u', 'can', 'p'], ['tench', 'a tench', 'c', 'fish', 'r'], ['rudd', 'a rudd', 'c', 'fish', 'r'], ['chub', 'a chub', 'c', 'fish', 'd'],
  ['dace', 'a dace', 'c', 'fish', 'd'], ['barbel', 'a barbel', 'u', 'long', 'd'], ['gar', 'a gar', 'u', 'long', 'e'], ['gar2', 'an alligator gar. it is not happy.', 'r', 'big', 'e'],
  ['bowfin', 'a bowfin', 'u', 'long', 'e'], ['burbot', 'a burbot', 'u', 'long', 'i'], ['smelt', 'a smelt', 'c', 'fish', 'i'], ['whitefish', 'a whitefish', 'c', 'fish', 'i'],
  ['char', 'an arctic char', 'u', 'fish', 'i'], ['grayling', 'a grayling', 'u', 'fish', 'i'], ['loach', 'a loach', 'c', 'long', 'r'], ['gudgeon', 'a gudgeon', 'c', 'fish', 'r'],
  ['stickleback', 'a stickleback', 'c', 'fish', 'r'], ['mudfish', 'a mudfish', 'c', 'long', 'p'], ['piranha', 'a piranha, somehow', 'r', 'fish', 'e'], ['betta', 'a betta fish flaring at you', 'u', 'fish', 'r'],
  ['guppy', 'a guppy', 'c', 'fish', 'r'], ['pleco', 'a plecostomus stuck to the bobber', 'u', 'flat', 'p'], ['flounder', 'a flounder (wrong water)', 'u', 'flat', 'e'], ['sole', 'a sole. just the one.', 'u', 'flat', 'e'],
  ['mackerel', 'a mackerel', 'u', 'fish', 'e'], ['herring', 'a red herring', 'r', 'fish', 'e', 'it means nothing'], ['sardine', 'one sardine', 'c', 'fish', 'e'], ['anchovy', 'an anchovy with strong opinions', 'u', 'fish', 'e'],
  ['cod', 'a cod', 'u', 'fish', 'e'], ['haddock', 'a haddock', 'u', 'fish', 'e'], ['halibut', 'a halibut that fills the frame', 'r', 'flat', 'e'], ['swordfish', 'a swordfish', 'l', 'long', 'e', 'en garde'],
  ['marlin', 'a marlin. this is a pond.', 'l', 'long', 'e'], ['shark', 'a small shark', 'r', 'shark', 'e'], ['shark2', 'a shark that apologises', 'l', 'shark', 'e', '"sorry. sorry."'], ['ray', 'a stingray', 'r', 'flat', 'e'],
  ['octopus', 'an octopus', 'r', 'octo', 'e'], ['octopus2', 'an octopus holding eight rods', 'l', 'octo', 'e'], ['squid', 'a squid', 'u', 'octo', 'e'], ['jelly', 'a jellyfish', 'u', 'jelly', 'e'],
  ['jelly2', 'a jellyfish with no plan', 'c', 'jelly', 'e'], ['crab', 'a crab', 'c', 'crab', 'dp'], ['crab2', 'a crab walking sideways out of your life', 'u', 'crab', 'd'], ['crayfish', 'a crayfish', 'c', 'crab', 'r'],
  ['lobster', 'a lobster on parole', 'r', 'crab', 'e'], ['shrimp', 'a shrimp', 'c', 'crab', 'r'], ['shrimp2', 'a shrimp doing its best', 'u', 'crab', 'r'], ['turtle', 'a turtle', 'u', 'turtle', 'r'],
  ['turtle2', 'a turtle that was here before the pond', 'r', 'turtle', 'r'], ['frog', 'a frog', 'c', 'frog', 'r'], ['frog2', 'a frog that says nothing', 'c', 'frog', 'r'], ['frog3', 'a frog in a tiny hat', 'r', 'frog', 'r'],
  ['toad', 'a toad', 'c', 'frog', 'r'], ['newt', 'a newt', 'c', 'snake', 'r'], ['snake', 'a water snake', 'u', 'snake', 'r'], ['leech', 'a leech (it is attached)', 'c', 'snake', 'p'],
  ['duck', 'a duck', 'c', 'duck', 'dr'], ['duck2', 'a duck that will not let this go', 'u', 'duck', 'r'], ['duckling', 'a duckling. put it back.', 'u', 'duck', 'r'], ['goose', 'a goose. run.', 'r', 'duck', 'r'],
  ['swan', 'a swan, furious', 'r', 'duck', 'd'], ['clam', 'a clam', 'c', 'coin', 'd'], ['mussel', 'a mussel', 'c', 'coin', 'd'], ['oyster', 'an oyster with nothing inside', 'u', 'coin', 'e'],
  ['oyster2', 'an oyster with a pearl', 'l', 'ring', 'e'], ['snail', 'a snail', 'c', 'coin', 'r'], ['tadpole', 'a tadpole', 'c', 'fish', 'r'], ['tadpoles', 'a jar of tadpoles (who left this)', 'u', 'bottle', 'r'],
  // ── 밈 물고기 ──
  ['fish', 'a fish', 'c', 'fish', '*'], ['fish2', 'a smaller fish', 'c', 'fish', '*'], ['fish3', 'a fish that looks tired', 'c', 'fish', '*', 'it sighs'], ['fish4', 'a fish that owes you money', 'u', 'fish', '*'],
  ['fish5', 'a fish with a LinkedIn', 'u', 'fish', 'd'], ['fish6', 'a fish that is also a manager', 'u', 'fish', 'd'], ['fish7', 'a fish. it is fine. it is just a fish.', 'c', 'fish', '*'],
  ['fish8', 'a bass that plays bass', 'u', 'fish', 'd'], ['fish9', 'a carp with opinions', 'u', 'fish', 'd'], ['fish10', 'a fish that has read your posts', 'r', 'fish', 'd', 'it says nothing'],
  ['fish11', 'a fish that is late for something', 'c', 'fish', '*'], ['fish12', 'a fish that thinks it is a bird', 'u', 'fish', 'r'], ['fish13', 'the same fish as before', 'c', 'fish', '*', 'it remembers you'],
  ['fish14', 'a fish wearing your face', 'l', 'fish', 'e'], ['fish15', 'a fish that refuses', 'u', 'fish', '*'], ['fish16', 'a fish, allegedly', 'c', 'fish', '*'], ['fish17', 'a fish that just got off work', 'c', 'fish', 'p'],
  ['fish18', 'a fish holding a smaller fish', 'u', 'fish', 'd'], ['fish19', 'a fish holding a smaller fish holding a smaller fish', 'r', 'fish', 'd'], ['fish20', 'a fish that vapes', 'u', 'fish', 'p'],
  ['fish21', 'two fish in a trench coat', 'r', 'long', 'd'], ['fish22', 'a fish with a mortgage', 'u', 'fish', 'd'], ['fish23', 'a fish that did the math', 'u', 'fish', 'd', 'it checks out'],
  ['fish24', 'a fish going through it', 'c', 'fish', '*'], ['fish25', 'a fish that peaked in 2016', 'u', 'fish', 'p'], ['fish26', 'a fish, lowercase', 'c', 'fish', '*'], ['fish27', 'A FISH, UPPERCASE', 'u', 'big', '*'],
  ['fish28', 'a fish that speedruns being a fish', 'u', 'fish', 'd'], ['fish29', 'a fish in witness protection', 'r', 'fish', 'e'], ['fish30', 'a fish that unionised', 'u', 'fish', 'd'],
  ['fish31', 'a fish with the audacity', 'u', 'fish', '*'], ['fish32', 'a fish that will explain crypto to you', 'u', 'fish', 'p'], ['fish33', 'a fish that is not a fish (it is three eels)', 'r', 'long', 'p'],
  ['fish34', 'a fish that keeps receipts', 'u', 'fish', 'd'], ['fish35', 'a fish, but from the 90s', 'u', 'fish', 'p'], ['fish36', 'a fish that only eats at 3am', 'c', 'fish', '*'], ['fish37', 'a fish that texts back', 'r', 'fish', 'd'],
  ['fish38', 'a fish that does not text back', 'c', 'fish', '*'], ['fish39', 'a fish that already caught you', 'l', 'big', 'e', 'it lets you go'], ['fish40', 'a fish shaped like a fish', 'c', 'fish', '*'],
  ['fish41', 'a fish shaped like a boot', 'u', 'boot', 'p'], ['fish42', 'a fish that is a landlord', 'u', 'fish', 'd', 'rent is due'], ['fish43', 'a fish with a podcast', 'u', 'fish', 'd'],
  ['fish44', 'a fish that was in the group chat', 'u', 'fish', 'd'], ['fish45', 'a fish that left the group chat', 'u', 'fish', 'e'], ['fish46', 'a fish in a suit and no pants', 'u', 'fish', 'd'],
  ['fish47', 'a fish that is your boss now', 'r', 'fish', 'd'], ['fish48', 'a fish carrying a grudge', 'u', 'fish', 'r'], ['fish49', 'a fish carrying groceries', 'u', 'fish', 'd'], ['fish50', 'a fish that just moved here', 'c', 'fish', '*'],
  ['fish51', 'a fish that hates it here', 'c', 'fish', '*'], ['fish52', 'a fish that loves it here, unfortunately', 'c', 'fish', '*'], ['fish53', 'a fish from the other pond', 'u', 'fish', 'e'],
  ['fish54', 'a fish with a tiny sword', 'r', 'fish', 'e'], ['fish55', 'a fish with a tiny gun (fake)', 'r', 'fish', 'p'], ['fish56', 'a fish with a tiny guitar', 'u', 'fish', 'd'], ['fish57', 'a fish with a tiny hat', 'u', 'fish', '*'],
  ['fish58', 'a fish with two tiny hats', 'r', 'fish', '*'], ['fish59', 'a fish that is a bit much', 'c', 'fish', '*'], ['fish60', 'a fish that is not enough', 'c', 'fish', '*'], ['fish61', 'a fish that is exactly enough', 'l', 'fish', 'e'],
  ['fish62', 'a fish that said "no offence" first', 'u', 'fish', 'd'], ['fish63', 'a fish that is a bot', 'u', 'fish', 'p', 'beep'], ['fish64', 'a fish that is a resident (retired)', 'r', 'fish', 'd'],
  ['fish65', 'a fish that reposts', 'c', 'fish', 'p'], ['fish66', 'a fish that reads the comments', 'u', 'fish', '*', 'it is worse now'], ['fish67', 'a fish that wrote the comments', 'r', 'fish', 'd'],
  ['fish68', 'a fish that has been here the whole time', 'u', 'fish', 'r'], ['fish69', 'nice fish', 'u', 'fish', '*'], ['fish70', 'a fish that is a dog', 'r', 'fish', 'r', 'woof'], ['fish71', 'a fish that is a cat', 'r', 'cat', 'r'],
  ['fish72', 'a fish doing taxes', 'u', 'fish', 'd'], ['fish73', 'a fish that is a tax', 'u', 'paper', 'd'], ['fish74', 'a fish that skipped leg day', 'c', 'fish', '*'], ['fish75', 'a fish that never skips leg day (it has no legs)', 'u', 'fish', '*'],
  ['fish76', 'a fish that is buffering', 'u', 'fish', 'p'], ['fish77', 'a fish at 1% battery', 'u', 'fish', 'p'], ['fish78', 'a fish that is a sleep paralysis demon', 'r', 'ghost', 'e'], ['fish79', 'a fish that is your ex', 'r', 'fish', 'e'],
  ['fish80', 'a fish that is your ex\'s new fish', 'u', 'fish', 'e'], ['fish81', 'a fish that was promised something', 'u', 'fish', 'd'], ['fish82', 'a fish that will not elaborate', 'u', 'fish', '*'],
  ['fish83', 'a fish that elaborated too much', 'u', 'fish', 'd'], ['fish84', 'a fish that is a mood', 'c', 'fish', '*'], ['fish85', 'a fish that is a whole mood', 'u', 'big', '*'], ['fish86', 'a fish that is just a vibe (banned word)', 'u', 'fish', 'p'],
  ['fish87', 'a fish in a jar of pickles', 'u', 'bottle', 'p'], ['fish88', 'a fish that is a sandwich', 'u', 'flat', 'd'], ['fish89', 'a fish that thinks you are a fish', 'u', 'fish', '*'], ['fish90', 'a fish that is right, actually', 'r', 'fish', 'd'],
  ['fish91', 'a fish that is fine, thanks', 'c', 'fish', '*'], ['fish92', 'a fish that is NOT fine, thanks', 'c', 'fish', '*'], ['fish93', 'a fish that clapped', 'u', 'fish', 'd'], ['fish94', 'a fish that clapped back', 'u', 'fish', 'd'],
  ['fish95', 'a fish that is a horse', 'r', 'horse', 'e'], ['fish96', 'a fish that wants to speak to a manager', 'u', 'fish', 'd'], ['fish97', 'a fish that IS the manager', 'r', 'fish', 'd'], ['fish98', 'a fish from a stock photo', 'u', 'fish', 'd'],
  ['fish99', 'a fish that was in a 1951 film', 'u', 'reel', 'e'], ['fish100', 'a fish from the wall', 'u', 'meme', 'p'], ['fish101', 'a fish that follows you (in the app)', 'u', 'fish', 'd'], ['fish102', 'a fish that unfollowed you', 'c', 'fish', '*'],
  ['fish103', 'a fish that is drafting a reply', 'u', 'fish', 'd'], ['fish104', 'a fish that is a sequel', 'u', 'fish', 'd'], ['fish105', 'a fish that is a reboot nobody asked for', 'u', 'fish', 'p'], ['fish106', 'a fish, deep fried (the meme)', 'r', 'fish', 'p'],
  ['fish107', 'a fish that gets it', 'u', 'fish', '*'], ['fish108', 'a fish that does not get it', 'c', 'fish', '*'], ['fish109', 'a fish that gets it but pretends not to', 'r', 'fish', 'd'], ['fish110', 'a fish that is a pigeon (see: divorced)', 'r', 'pigeon', 'p'],
  ['fish111', 'a fish that lives in the pipe', 'c', 'fish', 'p'], ['fish112', 'a fish that owns the pipe', 'u', 'fish', 'p'], ['fish113', 'a fish frozen mid-sentence', 'u', 'fish', 'i'], ['fish114', 'a fish that is an ice cube', 'c', 'box', 'i'],
  ['fish115', 'a fish in a scarf', 'u', 'fish', 'i'], ['fish116', 'a fish that survived the winter and wants credit', 'u', 'fish', 'i'], ['fish117', 'a fish that will haunt this pond', 'r', 'ghost', 'i'], ['fish118', 'a fish from the deep end with a story', 'r', 'big', 'e'],
  ['fish119', 'a fish that saw the bottom', 'r', 'fish', 'e', 'it will not say'], ['fish120', 'a fish that is the bottom', 'l', 'big', 'e'],
  // ── 잡동사니·사람·기타 ──
  ['boot', 'a boot', 'c', 'boot', '*'], ['boot2', 'the other boot', 'u', 'boot', '*', 'now you have a pair'], ['can', 'a tin can', 'c', 'can', 'p'], ['can2', 'a can of something from 1974', 'u', 'can', 'p'],
  ['weed', 'seaweed. in a pond.', 'c', 'weed', 'r'], ['weed2', 'weeds with something in them', 'u', 'weed', 'r'], ['log', 'a log', 'c', 'log', 'r'], ['log2', 'a log that is a crocodile (it is not)', 'u', 'log', 'r'],
  ['fax', 'a fax machine', 'u', 'fax', 'p', 'it is still receiving something'], ['printer', 'the printer. so this is where it went.', 'u', 'fax', 'p'], ['tax', 'a tax notice. addressed to you.', 'u', 'paper', 'p'],
  ['letter', 'a letter that says "we need to talk"', 'u', 'paper', 'p'], ['resume', 'someone\'s résumé, laminated', 'u', 'paper', 'p'], ['cat', 'a wet cat (angry)', 'u', 'cat', 'r'], ['cat2', 'a wet cat (calm, which is worse)', 'r', 'cat', 'r'],
  ['brick', 'a brick with a note tied to it', 'u', 'brick', 'p', '"no"'], ['brick2', 'a brick. no note. just a brick.', 'c', 'brick', 'p'], ['tape', 'a VHS tape, unlabeled', 'u', 'tape', 'p'], ['tape2', 'a VHS tape labeled "DO NOT"', 'r', 'tape', 'p'],
  ['reel', 'a film reel from {film}', 'u', 'reel', 'e'], ['meme', 'a shitpost from the wall', 'u', 'meme', 'p'], ['phone', "someone's phone. it's ringing.", 'u', 'phone', 'p'], ['phone2', 'your phone. how.', 'r', 'phone', 'p'],
  ['resident', '{resident}, soaking wet', 'r', 'person', '*'], ['resident2', '{resident}, who was hiding down there', 'r', 'person', 'e'], ['grandma', 'a grandma', 'r', 'person', 'r', 'she is not pleased'],
  ['grandma2', 'a grandma who says you\'ve gotten thin', 'r', 'person', 'r'], ['guy', 'a guy named Kevin', 'u', 'person', '*'], ['intern', 'an unpaid intern (still unpaid)', 'u', 'person', 'd'], ['landlord', 'your landlord', 'r', 'person', 'd', 'rent is due'],
  ['peasant', 'a medieval peasant', 'r', 'person', 'e'], ['knight', 'a knight with no plan', 'r', 'person', 'e'], ['horse', 'a horse in a suit', 'r', 'horse', 'd'], ['groupchat', 'the group chat', 'r', 'phone', 'd', '47 unread'],
  ['bottle', 'a bottle with a message', 'u', 'bottle', 'd', '"help" — from you, last week'], ['bottle2', 'a bottle with no message', 'c', 'bottle', 'd'], ['key', 'a key to something', 'u', 'key', 'p'], ['key2', 'a key to nothing', 'c', 'key', 'p'],
  ['ring', 'a ring', 'r', 'ring', 'e'], ['ring2', 'a ring that says "call me"', 'r', 'ring', 'e'], ['shoe', 'a single crocs', 'c', 'shoe', 'p'], ['shoe2', 'a very fast shoe', 'u', 'shoe', 'p'], ['sock', 'the missing sock', 'u', 'sock', 'p'],
  ['bag', 'a bag of something heavy', 'u', 'bag', 'e'], ['bag2', 'a bag that is just water', 'c', 'bag', '*'], ['box', 'a box that says FRAGILE', 'u', 'box', 'p'], ['box2', 'a box that is clearly breathing', 'r', 'box', 'e'],
  ['chair', 'a chair', 'u', 'chair', 'p'], ['chair2', 'an office chair, still spinning', 'u', 'chair', 'p'], ['bike', 'a bicycle', 'u', 'bike', 'p'], ['bike2', 'a bicycle that is yours (stolen 2019)', 'r', 'bike', 'p'],
  ['bone', 'a bone', 'c', 'bone', 'e'], ['bone2', 'a bone that is definitely from a chicken', 'u', 'bone', 'e'], ['coin', 'a coin', 'c', 'coin', 'd'], ['coin2', 'a coin from a country that no longer exists', 'u', 'coin', 'e'],
  ['hat', 'a hat', 'c', 'hat', '*'], ['hat2', 'a hat with a smaller hat on it', 'u', 'hat', '*'], ['ghost', 'an 8-foot ghost', 'l', 'ghost', 'e', 'it was here first'], ['ghost2', 'a 4-foot ghost (the sequel)', 'r', 'ghost', 'e'],
  ['moon', 'the moon', 'l', 'moon', 'e'], ['moon2', 'the moon\'s reflection (it counts)', 'u', 'moon', '*'], ['mirror', 'your own reflection. it waves.', 'l', 'mirror', '*'], ['pigeon', 'a divorced pigeon', 'l', 'pigeon', 'p', 'he does not want to talk about it'],
  ['duckboat', 'a rubber duck the size of a boat', 'r', 'duck', 'd'], ['ice', 'a block of ice with a fish inside, waiting', 'u', 'box', 'i'], ['ice2', 'a block of ice with a phone inside, still ringing', 'r', 'box', 'i'],
  ['nothing', 'nothing', 'c', 'weed', '*', 'you feel it though'], ['nothing2', 'nothing, but heavier', 'u', 'bag', 'e'], ['you', 'you, from tomorrow', 'l', 'person', 'e', '"don\'t"'],
  ['mgmt', 'The Management', 'l', 'person', '*', '"locking this. take it to DMs."'],
] as const;

export const KEYS = new Set(ITEMS.map((r) => r[0]));
