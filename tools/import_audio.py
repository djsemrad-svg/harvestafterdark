"""Daniel's music, ambience and sound effect uploads (Nov 22) -> res://audio/.
python3 tools/import_audio.py <folder with the zips and wavs> <project root>

music/<slug>.ogg     the Mystery 1-2, Action 1-2 and Adventure 1-2 tracks, leaving out the sci-fi ones (cyber, mech,
                     space, synthwave), each brought to the same loudness (-16 LUFS) with a fixed gain so the
                     dynamics stay as written. Which track plays where is in scripts/autoload/soundscape.gd.
ambience/<slug>.ogg  the 18 Ambiance_* loops at -24 LUFS (they sit under the music), fixed gain so loops stay seamless.
sfx/<slug>.ogg       the Home Sound Effects the game uses, mono, peaks at -3 dB.
"""
import glob
import os
import re
import subprocess
import sys
import tempfile
import zipfile

SRC, ROOT = sys.argv[1], sys.argv[2]
OUT = os.path.join(ROOT, "audio")

# file name in the packs -> slug (None = left out: sci-fi)
MUSIC = {
    "Battle Encounter": "battle_encounter", "BossBattle": "boss_battle", "Long Preparation": "long_preparation",
    "Magic Fx 7": "magic_fx_7", "jump_run_duck": "jump_run_duck",
    "Bipedal Mech": None, "Mega Bot Bay": None, "Mega-bot-pipes-forest": None, "mega-bot-pipes under": None,
    "cyber_runner": None, "cyberpunk-street": None,
    "Nesquence": "nesquence", "NeverEndingRace": "never_ending_race", "Warped Caves": "warped_caves",
    "moonlight": "moonlight", "outrunner": "outrunner",
    "Space Rider": None, "space-marine-theme": None, "space-ray": None, "spaceship shooter ": None,
    "warped vehicles": None, "warped-shooting-fx": None,
    "Going Up": "going_up", "arcade": "arcade", "dark-happy-world": "dark_happy_world", "exploration": "exploration",
    "fantasy Dragon": "fantasy_dragon", "happywalking": "happy_walking", "hurry_up_and_run": "hurry_up_and_run",
    "chibi-robot-b": None,
    "Hurt_and_heart": "hurt_and_heart", "Maniac": "maniac", "joyful": "joyful", "magic cliffs": "magic_cliffs",
    "summer nights": "summer_nights", "up_and_right": "up_and_right", "world wanderer": "world_wanderer",
    "megabot": None, "synthwave-palms": None,
    "Dark Ambient 1": "dark_ambient_1", "Dark Ambient 2": "dark_ambient_2", "Dark Ambient 3": "dark_ambient_3",
    "Distalgia": "distalgia", "anxiety": "anxiety", "dark dungeon": "dark_dungeon", "expansion": "expansion",
    "industrial": "industrial", "cyber city 2-b": None, "cyberpunk city 2": None, "dark space": None,
    "Last Journey": "last_journey", "Lost_in_thought": "lost_in_thought", "Magic Fx 6": "magic_fx_6",
    "into_the_woods": "into_the_woods", "lost_and_notfound": "lost_and_notfound", "mystery": "mystery",
    "mystic-forest": "mystic_forest", "neon-alley": None,
}
SFX = {
    "Pulling drawer": "drawer", "Pulling Drawe": "drawer_long", "Zipper": "zipper", "Turning pages": "pages",
    "Writing": "writing", "Pouring Water": "pour", "Boiling": "boiling", "Fork Drop": "drop", "Chair dragging": "drag",
    "Sink water drop": "drip", "Turning liquid": "slosh", "Cutlery drop": "cutlery", "Knife drop": "knife_drop",
    "Footsteps": "footsteps", "Drawing fast": "sketch",
}


def loudness(path):
    r = subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128", "-f", "null", "-"],
                       capture_output=True, text=True)
    m = re.findall(r"I:\s+(-?[\d.]+) LUFS", r.stderr)
    return float(m[-1]) if m else -16.0


def encode(src, dst, target, q, mono=False, peak_only=False):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if peak_only:
        r = subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", "-i", src, "-af", "volumedetect", "-f", "null", "-"], capture_output=True, text=True)
        mx = float(re.findall(r"max_volume: (-?[\d.]+) dB", r.stderr)[0])
        gain = -3.0 - mx
    else:
        gain = target - loudness(src)
    af = "volume=%.2fdB,alimiter=limit=0.95:level=false" % gain
    cmd = ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y", "-i", src, "-af", af, "-c:a", "libvorbis", "-q:a", str(q)]
    if mono:
        cmd += ["-ac", "1"]
    subprocess.run(cmd + ["-ar", "44100", dst], check=True)


tmp = tempfile.mkdtemp()
for z in glob.glob(os.path.join(SRC, "*.zip")):
    if re.search(r"(ACTION_PACK|Adventure_pack|adventure_pack|Mystery|Home_Sound)", os.path.basename(z)):
        with zipfile.ZipFile(z) as zf:
            zf.extractall(os.path.join(tmp, os.path.basename(z)))
n = 0
for f in glob.glob(os.path.join(tmp, "**", "*.ogg"), recursive=True):
    name = os.path.splitext(os.path.basename(f))[0]
    if name.startswith("._") or name not in MUSIC or MUSIC[name] is None:
        continue
    encode(f, os.path.join(OUT, "music", MUSIC[name] + ".ogg"), -16.0, 2)
    n += 1
for f in glob.glob(os.path.join(tmp, "**", "*.wav"), recursive=True):
    name = os.path.splitext(os.path.basename(f))[0]
    if name in SFX:
        encode(f, os.path.join(OUT, "sfx", SFX[name] + ".ogg"), 0, 3, mono=True, peak_only=True)
        n += 1
for f in glob.glob(os.path.join(SRC, "*Ambiance_*.wav")):
    m = re.search(r"Ambiance_(.+?)_Loop", os.path.basename(f))
    if not m:
        continue
    slug = m.group(1).lower()
    encode(f, os.path.join(OUT, "ambience", slug + ".ogg"), -24.0, 1)
    n += 1
print("audio files:", n)
