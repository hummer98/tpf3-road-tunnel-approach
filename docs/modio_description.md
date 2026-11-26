# mod.io page text

The in-game uploader has no description field: paste this into the mod.io web page (or send it with the API's Edit Mod). The name and the summary are those of `_metadata/modinfo.json`.

**Summary:** Takes a street down into a road tunnel between retaining walls: the whole width, or only the centre with one-way side streets on top. / 道路を擁壁のあいだから地下へ下ろす。全幅か、中央だけ（側道は地上）。

## English

Two road constructions take a street underground in one placement, between concrete retaining walls with coping and a portal cover. Both are under **Roads > Road Constructions**. The bottom ends in a 30 m vanilla car tunnel that your own tunnel can connect to.

### Road Tunnel Approach: the whole street goes down

Snap it to the end of a street. It lays a flat approach street, the descent in an open trench, the portal with its cover and the tunnel stub, and cuts the terrain around it. The approach becomes an ordinary street once built, so your roads join it like any street.

- Street type: Small, Medium and Large Street, Small and Medium Country Road, One- and Two-Lane Highway (one-way), or two lanes for motor vehicles only (8 m, no sidewalks; this mod's own street).
- Only the flat approach keeps the sidewalks: the descent into the tunnel has the same lanes with narrow shoulders and no sidewalks, and the retaining walls take that width, so the ramp is no wider.
- Up to three streets side by side (a divided highway or 2+1 with the one-way highways).
- Ramp length 40–100 m, approach length 2–50 m, underground depth 13–25 m, slope curvature (five shapes), retaining wall 1.5 m (with a parapet) or 3.4 m, traffic side and direction.
- Portal cover length 12–24 m (18 m initially; it starts 6 m in front of the portal). The mod setting **Initial portal cover length** picks the value new ramps start on.
- Ground slope along and across (−20 to +20%): the walls, coping and cover follow sloped ground. The steepest grade of the settings and the measured slope of the ground under the cursor are shown under the build cursor.

### Median Tunnel Approach: only the centre goes down

A tunnel approach across a whole town street leaves no street for houses to front. Here a two-lane centre goes down into the tunnel with the same walls, coping and cover, and a **one-way side street each side stays on the surface**, sidewalk outside, right against the coping. Placed on a four-lane street it is that street's 24 m across.

- Entry street: 2, 4 or 6 lanes (one lane in each side street with 2 and 4, two with 6).
- Centre street: two lanes for motor vehicles only (initial setting), Small Street, Country Road or One-Lane Highway.
- The side streets are as long as the walls and the portal cover together, so they follow the ramp length, depth and slopes. Once built they are ordinary streets: the town builds houses on their outer side, none on the wall side.
- **You draw the fork and the merge yourself.** I wanted this to be one piece that joins a four-lane street cleanly at both ends. I tried every way I could find and the game would not have it. Sorry: this part is yours to draw. Nothing joins the side streets to the road: draw an S-curve from the road out to each side street's near end, and join their far ends back past the portal cover. The street menu has the one-lane side street for this: **Side street (one-way, one sidewalk)**, with the small streets. Draw it the way its traffic runs and its sidewalk is on the right, the outside of the trench with right-hand traffic. (With entry 6 the side streets have two lanes; join them with an ordinary street.)
- Retaining wall, ramp length, approach length (30–50 m, room for the fork), depth, slope curvature, traffic side, traffic direction (highway centre) and ground slope as on the full-width ramp.

### Notes

- Start a new game with this mod.
- Removing it from a save with placed ramps gives a warning: the ramps, the median's side streets and the cars-only street are this mod's constructions and street types.
- Checked in the game with test tools: placing both constructions, cars on the centre and the side streets, the side streets' length, and the fork and the merge drawn with the menu's side street. Not yet checked: placing it and drawing the fork and the merge by hand with the game's own build menu and road tool, left-hand traffic, and the median on sloped ground.

Credits: the ramp's shape (the descent's curve, the portal position, the retaining walls, their top, the portal cover and the terrain cut) follows Railway Tunnel Approach by Enivia (mod.io 6497196), rescaled for roads. Thank you, Enivia. The code and the wall meshes are this mod's own; the walls use the base game's light concrete.

License: MIT. Source code: https://github.com/hummer98/tpf3-road-tunnel-approach

## 日本語

道路を、コンクリートの擁壁・笠石・ポータル天蓋のあいだから地下へ下ろす建設物が2つ入っています。どちらも建設メニューの **道路 > 道路建設** にあります。底はバニラの自動車用トンネル（30 m）で終わり、自分で敷いたトンネルをつなげられます。

### 道路地下進入路：道路の全幅を下ろす

道路の端に接続して置きます。手前の平らな道路、掘り割りの下り坂、ポータルと天蓋、トンネルの端を建て、まわりの地形を掘り下げます。手前の道路は建設後ふつうの道路になるので、ほかの道路と同じようにつなげられます。

- 道路種類：街道（小・中・大）、田舎道（小・中）、一方通行の1車線・2車線高速道路、歩道なしの2車線の車専用（8 m。この MOD の道路）。
- 歩道が残るのは手前の平らな道路だけです。トンネルへの下り坂は、同じ車線に細い路肩が付いた歩道のない道路になり、その幅は擁壁にあてるので、ランプの幅は広がりません。
- 3本まで並べられます（一方通行の高速道路で、上下線のそろった道路や 2+1）。
- ランプの長さ 40〜100 m、手前の道路の長さ 2〜50 m、地下深度 13〜25 m、勾配カーブ（5種類）、擁壁 1.5 m（壁高欄付き）か 3.4 m、通行区分、進行方向。
- ポータル天蓋の長さ 12〜24 m（初期設定 18 m。天蓋は坑口の 6 m 手前から始まります）。MOD の設定「天蓋の長さの初期値」で、新しく置くときの値を選べます。
- 地面の縦断・横断勾配（−20〜+20%）：傾斜地で擁壁・笠石・天蓋が地面に沿います。いまの設定での最大勾配と、カーソルの下の地面の勾配を、配置カーソルの下に出します。

### 道路中央の地下進入路：中央だけを下ろす

道路の全幅を地下へ下ろすと、建物が面する道がなくなります。こちらは2車線の中央の道だけを同じ擁壁・笠石・天蓋のあいだから地下へ下ろし、**両側に一方通行の側道を地上に残します**（歩道は外側、笠石のすぐ脇）。4車線の道に置くと、全体の幅はその道と同じ 24 m です。

- 入口の道：2・4・6 車線（2 と 4 では側道が各1車線、6 では各2車線）。
- 中央の道：2車線の車専用（初期設定）、街道（小）、田舎道（小）、1車線高速道路。
- 側道は擁壁とポータル天蓋を合わせた長さで建ち、ランプの長さ・深さ・勾配に合わせて伸び縮みします。建設後はふつうの道路になり、町は側道の外側に建物を建てます。擁壁の側には建ちません。
- **分かれ目と合流は自分で引きます。**本当は、4車線の道の前後にそのままきれいにつながる、ひとまとまりの形にしたかったのですが、どうやってもできませんでした。すみませんが、ここは自分で引いてください。 側道はどこにもつながっていません。道路から各側道の手前の端へ S 字に道を引き、天蓋の先で遠い端どうしを道路に戻してください。そのための1車線の側道が、道路のメニューの「街道（小）」の並びにあります：**側道（片側歩道の一方通行）**。車の進む向きに引くと歩道が右に来て、右側通行では掘り割りの外側になります（入口 6 の側道は2車線なので、ふつうの道路でつないでください）。
- 擁壁・ランプの長さ・手前の道路の長さ（30〜50 m。分かれ目を引く余地）・地下深度・勾配カーブ・通行区分・進行方向（中央が高速道路のとき）・地面の勾配は、全幅のものと同じです。

### 注意

- 新しいゲームで始めてください。
- ランプを置いたセーブからこの MOD を外すと警告が出ます。ランプ、中央の地下進入路の側道、車専用の道路は、この MOD の建設物と道路だからです。
- ゲームで（試験用のツールで）確認したもの：2つの建設物を置けること、中央と側道を車が通ること、側道の長さ、メニューの側道で分かれ目と合流を引けること。まだ確認していないもの：ゲームの建設メニューと道路のツールを手で使って置き、分かれ目と合流を引くこと、左側通行、傾斜地での中央の地下進入路。

クレジット：ランプの形（降り方の曲線、ポータルの位置、擁壁、笠石、ポータル天蓋、地形の掘り下げ）は Enivia さんの Railway Tunnel Approach（mod.io 6497196）にならって道路向けに作り直しました。Enivia さん、ありがとうございます。コードと擁壁のメッシュはこの MOD のもので、擁壁の素材はバニラの明るいコンクリートを使います。

ライセンス：MIT。ソースコード：https://github.com/hummer98/tpf3-road-tunnel-approach
