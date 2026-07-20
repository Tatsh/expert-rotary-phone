//
//  CharaData.mm
//  pop'n rhythmin
//
//  Reconstructed from Ghidra project rb420, program PopnRhythmin.
//  The 30 built-in characters (the pop'n music cast). Names, bios and skill
//  names are constant NSStrings extracted from the Mach-O __cfstring table
//  (mostly UTF-16; entry 24's skill name is 8-bit ASCII). Table @ 0x133298
//  (30 x 16 bytes: {NSString* name, NSString* info, NSString* skillName,
//  short skillId, short rarity}); accessor GetHardCodeCharaDataStruct @
//  0xcb958. Every Japanese string carries an inline English translation
//  comment.
//

#import "CharaData.h"

#include <cassert>

// The 30 built-in characters (Ghidra: table @ 0x133298, PTR_cf_00_00133298).
// skillId indexes the character's active skill; rarity is 100/70/50.
static const CharaDataStruct kCharaData[30] = {
    // 0: Mimi  (skillId=16, rarity=100)
    {@"ミミ", // Mimi
     @"ハロー！ミミだよ〜！\n一緒にポップンリズミンをプレーしよ"
     @"！", // Hello! I'm Mimi~! Let's play pop'n rhythmin
            // together!
     @"Love & Peace！",
     16,
     100}, // skill: "Love & Peace!"
    // 1: Nyami  (skillId=17, rarity=100)
    {@"ニャミ",                                             // Nyami
     @"はーい！ニャミだよ〜！\nWe love ポップンリズミン！", // Hi!
                                                            // I'm
                                                            // Nyami~!
                                                            // We
                                                            // love
                                                            // pop'n
                                                            // rhythmin!
     @"We Love！",
     17,
     100}, // skill: "We Love!"
    // 2: Nakaji  (skillId=9, rarity=100)
    {@"ナカジ", // Nakaji
     @"莫迦莫迦しい世界を貶むメガネ男子。\n汚れちまつた空気にメガネ"
     @"が曇るんだ。", // A bespectacled boy who scorns this foolish
                      // world; his glasses fog in the sullied air.
     @"意味なんか無いし",
     9,
     100}, // skill: "It has no meaning anyway"
    // 3: Gokusotsu-kun  (skillId=15, rarity=100)
    {@"ごくそつくん", // Gokusotsu-kun
     @"ひょひょひょひょひょ〜\nボクはごくそつくんだよ〜。\nと〜って"
     @"も偉いんだ^^", // Hyo hyo hyo~ I'm Gokusotsu-kun~. I'm ve~ry
                      // important ^^ (gokusotsu = a jailer of hell)
     @"とっても偉いんだよ〜",
     15,
     100}, // skill: "I'm really important~"
    // 4: Roku  (skillId=5, rarity=50)
    {@"六", // Roku
     @"剣と言の極致を究めんと世をさすらう\n憂国のヒップロックサムラ"
     @"イ。", // A patriotic hip-rock samurai wandering the world
              // after the ultimate blade and word.
     @"六花舞う",
     5,
     50}, // skill: "Six-petal snow dances" (rokka=snowflake)
    // 5: Yuuri  (skillId=0, rarity=50)
    {@"ユーリ", // Yuuri
     @"200年の眠りについていたヴァンパイア。\n起きたら暇だったので"
     @"バンドを作ってみた。", // A vampire who slept 200 years.
                              // Bored on waking, he decided to form
                              // a band.
     @"永遠の１",
     0,
     50}, // skill: "Eternal 1"
    // 6: Mister KK  (skillId=12, rarity=100)
    {@"ミスターKK", // Mister KK
     @"表の顔は清掃員。\n裏の顔は「掃除屋」という異名を持つ\nスナイ"
     @"パーなんだって。", // By day a janitor; by night a sniper
                          // known by the alias 'the Cleaner.'
     @"掃除屋",
     12,
     100}, // skill: "The Cleaner"
    // 7: Shou  (skillId=3, rarity=50)
    {@"翔", // Shou
     @"青春真っ盛りのバスケ少年。\nこのシュートが決まったら、\nあの"
     @"子に想いを伝えよう!", // A basketball boy in the prime of
                             // youth. If this shot goes in, I'll
                             // confess to her!
     @"キャプテンナンバー",
     3,
     50}, // skill: "Captain Number"
    // 8: Timer  (skillId=9, rarity=100)
    {@"タイマー", // Timer
     @"「生まれつきアイドル。てゆーか妖精?"
     @"」\nな歌ってしゃべれるミュージシャン。", // A singing,
                                                // talking musician
                                                // who's 'a born
                                                // idol - or rather,
                                                // a fairy?'
     @"時間よ戻れ☆",
     9,
     100}, // skill: "Time, turn back"
    // 9: Jack  (skillId=10, rarity=100)
    {@"ジャック", // Jack
     @"毒素大気、異世界から流転。\n時の早鐘打ち鳴らし、\n奴を追う暗"
     @"殺旅行エンドレス。", // Toxic skies, adrift from another
                            // world; an endless assassination
                            // journey chasing his quarry.
     @"暗躍掻潜",
     10,
     100}, // skill: "Covert maneuvering"
    // 10: Leo-kun  (skillId=12, rarity=100)
    {@"レオくん", // Leo-kun
     @"クラブのＤＪもしているミュージシャン。\nセクシーなため息に女"
     @"の子はメロメロ！", // A musician who also DJs at clubs. His
                          // sexy sighs make the girls swoon!
     @"チョコレートジャンキー",
     12,
     100}, // skill: "Chocolate Junkie"
    // 11: Kojirou  (skillId=8, rarity=100)
    {@"小次郎", // Kojirou
     @"きっとぼくも\n父ちゃん母ちゃんみたいな\n立派な鳥になるんだ"
     @"！", // Surely I too will grow into a fine bird, just like
            // Mom and Dad!
     @"その翼を試すとき",
     8,
     100}, // skill: "When you test those wings"
    // 12: Lolly Pony  (skillId=14, rarity=100)
    {@"ローリー・ポニー", // Lolly Pony
     @"ぴょんぴょんお花も飛び出す\n跳ねごこちサイコーな\nスプリング"
     @"・ポニー。", // A spring pony with the best bouncy feel -
                    // flowers pop out as it hops!
     @"スプリングポニー",
     14,
     100}, // skill: "Spring Pony"
    // 13: Moffy  (skillId=13, rarity=100)
    {@"モッフィー",                               // Moffy
     @"もふもふ？！\nもふ！\nもっふっふぉー！！", // Moff-moff?!
                                                  // Moff!
                                                  // Moffuffo-!!
     @"魅惑のモフガード",
     13,
     100}, // skill: "Enchanting Moff Guard"
    // 14: Star Nyan  (skillId=7, rarity=100)
    {@"スター★にゃん", // Star Nyan
     @"いまは冴えないエキストラねこだけど、\n大スターになるのを夢見"
     @"てるんだって！", // A dull extra cat for now, but dreaming of
                        // becoming a big star!
     @"ナメンナヨゥ",
     7,
     100}, // skill: "Don't underestimate me"
    // 15: Junes  (skillId=14, rarity=100)
    {@"ジュネス", // Junes
     @"遺伝子とかいじられた花はどんどん増えて\nもっともっと実験され"
     @"て\nもっともっと増えます。", // Gene-tinkered flowers
                                    // multiply, get experimented on
                                    // more and more, and multiply
                                    // more.
     @"増殖する遺伝子",
     14,
     100}, // skill: "Proliferating genes"
    // 16: Popcon  (skillId=13, rarity=100)
    {@"ポプコン", // Popcon
     @"パーティーで子供たちに大人気の\n最新型ポップコーンマシン"
     @"。", // The latest-model popcorn machine, hugely popular
            // with kids at parties.
     @"安心ポップンコーン",
     13,
     100}, // skill: "Reliable Popcorn"
    // 17: Ima  (skillId=6, rarity=50)
    {@"イマ",                                     // Ima
     @"神々へ踊りで祈りを捧げる\n孤高の踊り手。", // A solitary
                                                  // dancer who
                                                  // offers prayers
                                                  // to the gods
                                                  // through dance.
     @"豊穣のおどり",
     6,
     50}, // skill: "Dance of the harvest"
    // 18: Minitts  (skillId=2, rarity=50)
    {@"ミニッツ", // Minitts
     @"ラブリーキュートなちびっこアイドル☆\nぴょんぴょんいっしょに"
     @"おどっちゃお〜！", // A lovely, cute little idol. Let's hop
                          // and dance together~!
     @"ぴょんぴょん！",
     2,
     50}, // skill: "Hop hop!"
    // 19: Poet  (skillId=4, rarity=50)
    {@"ポエット", // Poet
     @"立派な天使になるための\n修行にやってきた女の子。\n泳ぐのはニ"
     @"ガテ！", // A girl training to become a fine angel. Bad at
                // swimming!
     @"お空のお散歩",
     4,
     50}, // skill: "A stroll in the sky"
    // 20: Lotte  (skillId=8, rarity=100)
    {@"ロッテ",                                             // Lotte
     @"一粒だけ残った約束の欠片\nいつ彼方はとりにくるの？", // A
                                                            // single
                                                            // remaining
                                                            // shard
                                                            // of a
                                                            // promise
                                                            // -
                                                            // when
                                                            // will
                                                            // you
                                                            // come
                                                            // to
                                                            // claim
                                                            // it?
     @"お姉ちゃんどこ？",
     8,
     100}, // skill: "Where's big sister?"
    // 21: Nia  (skillId=1, rarity=50)
    {@"ニア", // Nia
     @"抑えた指のすきまから\nこぼれ出したこの想い。\nもう、きっと戻"
     @"れない…。", // These feelings spilling through my pressed
                   // fingers. Surely there's no going back now...
     @"逃げたくない",
     1,
     50}, // skill: "I don't want to run away"
    // 22: Kanoko  (skillId=15, rarity=100)
    {@"鹿ノ子", // Kanoko
     @"ヒラリヒラリと月を駆ける。\nアタシウサギ。\nマルデ飛天狗"
     @"。", // Fluttering, I race across the moon. I'm a rabbit.
            // Just like a flying tengu.
     @"アタシ駆ける",
     15,
     100}, // skill: "I dash onward"
    // 23: Usanuko  (skillId=11, rarity=100)
    {@"うさぬこ", // Usanuko
     @"ギャラクシーの\nトップアイドルことぉ〜・・・\nうさぬこだぬっ"
     @"っ♥", // The galaxy's top idol, y'know~... it's Usanuko-danu!
     @"絶対アイドル",
     11,
     100}, // skill: "Absolute Idol"
    // 24: Alto  (skillId=17, rarity=100)
    {@"アルト",                                                   // Alto
     @"「ワタシノナマエハアルト、\nワタシノウタヲ　キイテネ！」", // "My name is Alto. Please listen to my song!" (robotic katakana)
     @"Hello World!",
     17,
     100}, // skill: "Hello World!"
    // 25: Lisette  (skillId=10, rarity=100)
    {@"リゼット", // Lisette
     @"スウェーデンの寒さに負けない元気さで\n街中の評判なスクールガ"
     @"ール。", // A schoolgirl, talk of the town, with energy that
                // shrugs off Sweden's cold.
     @"癒しのカモミール",
     10,
     100}, // skill: "Soothing Chamomile"
    // 26: Judy  (skillId=11, rarity=100)
    {@"ジュディ", // Judy
     @"アメリカ西海岸育ちのジュディは\n歌もダンスもとってもＣＵＴＥ"
     @"＆ＳＥＸＹ！", // Raised on the US West Coast, Judy sings and
                      // dances super CUTE & SEXY!
     @"ブルーアイドダンス",
     11,
     100}, // skill: "Blue-Eyed Dance"
    // 27: Rie-chan  (skillId=16, rarity=100)
    {@"リエちゃん", // Rie-chan
     @"かわいい洋服を着るのも\n作るのも大好きな女の子。\n嫌いなもの"
     @"はなんにもないよ☆", // A girl who loves wearing and making
                           // cute clothes. Nothing she dislikes!
     @"みんなだいすき！",
     16,
     100}, // skill: "I love everyone!"
    // 28: Kagome  (skillId=18, rarity=70)
    {@"かごめ", // Kagome
     @"不思議な世界観の詩と朗読スタイルで\nカリスマ的人気を持つ少女"
     @"詩人。", // A girl poet of charismatic popularity, known for
                // surreal poetry and recitation.
     @"揺るがない心",
     18,
     70}, // skill: "An unshakeable heart"
    // 29: Knit  (skillId=19, rarity=70)
    {@"ニット", // Knit
     @"寂しげな眼差しとからみあう赤い糸・・・\nその先には誰が待って"
     @"るの？", // A lonely gaze and an entwining red thread... who
                // waits at its far end?
     @"編みこまれた絆",
     19,
     70}, // skill: "Woven bonds"
};

const CharaDataStruct *GetHardCodeCharaDataStruct(int index) {
    assert((index & 0xffff) < 30);
    return &kCharaData[index];
}
