#!/usr/bin/env python3
"""Icon packs for VOIDHOLD — resource, building, placement/warning, brand.

Shared visual language (art bible):
  - 48x48 grid, rounded dark-alloy badge for inventory-style icons
  - snow-white #E8EEF4 marks, amber #FFB020 / cyan #5FD4E8 accents
  - no text baked in (EN + AR localization rule)
  - silhouettes stay readable at 24 dp

Outputs SVG vector masters + 512px and 48px PNGs.

Usage: python3 gen_icons.py [--out-base DIR]
"""
import argparse, os
import cairosvg

SNOW, ALLOY, ALLOY_D, AMBER, CYAN, GREEN, RED, WARM = (
    "#E8EEF4", "#3A4750", "#26313B", "#FFB020", "#5FD4E8", "#35D07F", "#FF4D4D", "#FFC37A")

# ---------------------------------------------------------------- helpers --
def badge(inner, badge_fill=ALLOY_D):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <rect x="2" y="2" width="44" height="44" rx="10" fill="{badge_fill}"/>
  <rect x="2" y="2" width="44" height="44" rx="10" fill="none" stroke="#46545F" stroke-width="1.6"/>
  <rect x="5" y="4.6" width="38" height="8" rx="4" fill="#FFFFFF" opacity="0.05"/>
  {inner}
</svg>"""

def plain(inner):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">{inner}</svg>"""

S = f'fill="none" stroke="{SNOW}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"'

# ------------------------------------------------------------ resources ----
def ico_stone():
    return badge(f"""
  <path d="M14 33 L17 20 L26 14 L34 19 L35 29 L28 35 Z" fill="{SNOW}" opacity="0.92"/>
  <path d="M17 20 L26 14 L28 22 L20 26 Z" fill="#FFFFFF"/>
  <path d="M28 22 L34 19 L35 29 L28 35 Z" fill="#B9C6D2"/>""")

def ico_alloy():
    return badge(f"""
  <path d="M12 28 h24 l-4 7 H16 Z" fill="{SNOW}"/>
  <path d="M15 19 h18 l3 7 H12 Z" fill="#C2CFDA"/>
  <path d="M18 11 h12 l3 6 H15 Z" fill="#93A5B3"/>""")

def ico_biomass():
    return badge(f"""
  <path d="M24 36 C18 30 17 20 24 12 C31 20 30 30 24 36 Z" fill="{GREEN}" opacity="0.9"/>
  <path d="M24 36 V18" stroke="#0F2418" stroke-width="2" stroke-linecap="round"/>
  <path d="M24 24 C21 22 19 19 19 16 M24 28 C27 26 29 23 29 20"
        fill="none" stroke="#0F2418" stroke-width="1.8" stroke-linecap="round"/>""")

def ico_ore():
    return badge(f"""
  <path d="M24 8 L31 20 L24 26 L17 20 Z" fill="{SNOW}"/>
  <path d="M14 22 L19 29 L14 36 L10 29 Z" fill="#9FB4C6"/>
  <path d="M34 22 L38 29 L33 36 L29 29 Z" fill="#9FB4C6"/>
  <path d="M24 27 L28 33 L24 39 L20 33 Z" fill="#C9D8E4"/>""")

def ico_stim():
    return badge(f"""
  <rect x="20" y="9" width="8" height="20" rx="4" fill="{SNOW}" transform="rotate(35 24 24)"/>
  <rect x="20" y="9" width="8" height="9" rx="4" fill="{AMBER}" transform="rotate(35 24 24)"/>
  <path d="M17 33 L14 38 M31 33 L34 38" fill="none" stroke="{AMBER}" stroke-width="2.4" stroke-linecap="round"/>""")

RESOURCES = {"stone": ico_stone, "alloy": ico_alloy, "biomass": ico_biomass,
             "ore": ico_ore, "stim": ico_stim}

# ------------------------------------------------------------- buildings ---
def ico_oxygen():
    return badge(f"""
  <rect x="17" y="30" width="14" height="6" rx="2" fill="{ALLOY}" stroke="#57666F" stroke-width="1"/>
  <rect x="16" y="21" width="16" height="8" rx="3.5" fill="{SNOW}"/>
  <rect x="18" y="12" width="12" height="8" rx="3.5" fill="#C6D3DE"/>
  <path d="M13 25 h3 M32 25 h3 M14 16 h4 M30 16 h4" stroke="{AMBER}" stroke-width="2.2" stroke-linecap="round"/>
  <circle cx="24" cy="7.5" r="1.8" fill="{CYAN}"/>""")

def ico_living():
    return badge(f"""
  <rect x="8" y="18" width="22" height="13" rx="6.5" fill="{SNOW}"/>
  <rect x="20" y="24" width="20" height="12" rx="6" fill="#C9D6E2"/>
  <rect x="13" y="22.5" width="3.6" height="3.6" rx="1" fill="{WARM}"/>
  <rect x="19.5" y="22.5" width="3.6" height="3.6" rx="1" fill="{WARM}"/>
  <rect x="27" y="28" width="3.6" height="3.6" rx="1" fill="{WARM}"/>
  <rect x="33" y="28" width="3.6" height="3.6" rx="1" fill="{WARM}"/>
  <rect x="33" y="32" width="4" height="4" rx="1" fill="{ALLOY}"/>""")

def ico_farmarea():
    return badge(f"""
  <path d="M8 32 A16 16 0 0 1 40 32 Z" fill="#BFE6C8" opacity="0.95"/>
  <path d="M12 32 A12 12 0 0 1 36 32 M16 32 A8 8 0 0 1 32 32"
        fill="none" stroke="{ALLOY}" stroke-width="2"/>
  <path d="M24 16 V12" stroke="{CYAN}" stroke-width="2.4" stroke-linecap="round"/>
  <path d="M6 32 h36" stroke="{SNOW}" stroke-width="2.6" stroke-linecap="round"/>""")

def ico_solar():
    return badge(f"""
  <rect x="19" y="30" width="10" height="7" rx="2" fill="{ALLOY}" stroke="#57666F" stroke-width="1"/>
  <path d="M24 30 V14" stroke="{SNOW}" stroke-width="2.8" stroke-linecap="round"/>
  <path d="M24 20 C28 17 29 13 27 9 M24 20 C20 17 19 13 21 9 M24 20 C24 15 26 12 24 8"
        fill="none" stroke="{CYAN}" stroke-width="2.4" stroke-linecap="round"/>
  <circle cx="24" cy="20" r="2.4" fill="{AMBER}"/>""")

def ico_storage():
    return badge(f"""
  <rect x="7" y="20" width="34" height="16" rx="3" fill="{SNOW}"/>
  <path d="M17 20 v16 M27 20 v16" stroke="#8FA0AE" stroke-width="2"/>
  <rect x="9" y="22" width="7" height="6" rx="1" fill="{AMBER}"/>
  <rect x="19" y="22" width="7" height="6" rx="1" fill="#9FB4C6"/>
  <rect x="29" y="22" width="7" height="6" rx="1" fill="{CYAN}"/>
  <path d="M7 20 L14 12 H34 L41 20" fill="{ALLOY}" stroke="#4E5C67" stroke-width="1"/>""")

def ico_elevator():
    return badge(f"""
  <rect x="10" y="33" width="28" height="5" rx="2" fill="{ALLOY}" stroke="#57666F" stroke-width="1"/>
  <rect x="19" y="18" width="10" height="15" rx="2" fill="#C2CFDA"/>
  <path d="M24 26 l-4.5 4 M24 26 l4.5 4 M24 19 l-4.5 4 M24 19 l4.5 4"
        fill="none" stroke="{AMBER}" stroke-width="2.4" stroke-linecap="round"/>
  <circle cx="24" cy="11" r="2" fill="{AMBER}"/>
  <path d="M14 33 V22 M34 33 V22" stroke="{SNOW}" stroke-width="2.4" stroke-linecap="round"/>""")

def ico_farm():
    return badge(f"""
  <rect x="12" y="20" width="17" height="16" rx="2" fill="{SNOW}"/>
  <circle cx="33" cy="28" r="8" fill="#B9C8D4"/>
  <circle cx="33" cy="28" r="3" fill="{ALLOY}"/>
  <path d="M16 20 v-5 h9 v5" fill="none" stroke="{SNOW}" stroke-width="2.4"/>
  <rect x="15" y="26" width="4" height="4" rx="1" fill="{AMBER}"/>""")

def ico_cantine():
    return badge(f"""
  <rect x="9" y="22" width="30" height="14" rx="3" fill="{SNOW}"/>
  <path d="M9 22 L14 15 H34 L39 22 Z" fill="{ALLOY}"/>
  <rect x="19" y="27" width="10" height="9" rx="1.5" fill="{WARM}"/>
  <path d="M15 27 h2 M31 27 h2" stroke="{AMBER}" stroke-width="2.2" stroke-linecap="round"/>""")

def ico_mine():
    return badge(f"""
  <rect x="8" y="31" width="32" height="5" rx="2" fill="{ALLOY}" stroke="#57666F" stroke-width="1"/>
  <rect x="15" y="17" width="18" height="14" rx="3" fill="{SNOW}"/>
  <circle cx="24" cy="24" r="4.5" fill="{ALLOY}"/>
  <path d="M12 17 h6 M30 17 h6" stroke="{AMBER}" stroke-width="2.2" stroke-linecap="round"/>
  <path d="M18 17 v-6 M24 17 v-8 M30 17 v-6" stroke="#9FB4C6" stroke-width="2" stroke-linecap="round"/>""")

def ico_mineshaft():
    return badge(f"""
  <path d="M10 36 L20 14 H28 L38 36" fill="none" stroke="{SNOW}" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M16 36 L22 24 H26 L32 36" fill="{ALLOY}"/>
  <circle cx="24" cy="11" r="2" fill="{AMBER}"/>
  <path d="M13 36 h22" stroke="{SNOW}" stroke-width="2.6" stroke-linecap="round"/>""")

def ico_oremine():
    return badge(f"""
  <path d="M14 37 L24 13 L34 37" fill="none" stroke="{SNOW}" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M24 20 V33" stroke="{CYAN}" stroke-width="2.6" stroke-linecap="round"/>
  <path d="M20 33 h8" stroke="{AMBER}" stroke-width="2.4" stroke-linecap="round"/>
  <path d="M17 37 h14" stroke="{SNOW}" stroke-width="2.6" stroke-linecap="round"/>
  <circle cx="24" cy="9.5" r="1.8" fill="{CYAN}"/>""")

def ico_factory():
    return badge(f"""
  <path d="M8 36 V22 l8 5 v-5 l8 5 v-5 l8 5 V36 Z" fill="{SNOW}"/>
  <rect x="32" y="12" width="6" height="14" rx="1.5" fill="{ALLOY}"/>
  <path d="M35 12 v-4" stroke="{AMBER}" stroke-width="2" stroke-linecap="round"/>
  <rect x="12" y="28" width="4" height="4" rx="1" fill="{WARM}"/>
  <rect x="20" y="28" width="4" height="4" rx="1" fill="{WARM}"/>""")

def ico_kitchen():
    return badge(f"""
  <path d="M10 22 h28 v4 a8 8 0 0 1 -8 8 H18 a8 8 0 0 1 -8 -8 Z" fill="{SNOW}"/>
  <path d="M14 22 v-4 M34 22 v-4" stroke="{SNOW}" stroke-width="2.4" stroke-linecap="round"/>
  <path d="M20 15 c-1.5 -2 1.5 -3 0 -5 M28 15 c-1.5 -2 1.5 -3 0 -5"
        fill="none" stroke="{CYAN}" stroke-width="2" stroke-linecap="round"/>
  <rect x="22" y="34" width="4" height="4" rx="1" fill="{AMBER}"/>""")

def ico_maintenance():
    return badge(f"""
  <path d="M24 10 a6.5 6.5 0 1 0 6.5 6.5 L27 20 l-3 -3 3.5 -3.5 a6.5 6.5 0 0 0 -3.5 -3.5 Z"
        fill="{SNOW}"/>
  <path d="M24 23 L14 33 a3 3 0 0 0 4.2 4.2 L28 27" fill="none" stroke="{AMBER}" stroke-width="3.4" stroke-linecap="round"/>
  <circle cx="24" cy="10" r="2" fill="{ALLOY_D}"/>""")

def ico_quarter():
    return badge(f"""
  <rect x="16" y="10" width="16" height="28" rx="4" fill="{SNOW}"/>
  <rect x="19" y="13" width="10" height="7" rx="2.5" fill="{CYAN}" opacity="0.85"/>
  <rect x="19" y="24" width="4" height="4" rx="1" fill="{WARM}"/>
  <rect x="25" y="24" width="4" height="4" rx="1" fill="{WARM}"/>
  <rect x="19" y="31" width="4" height="4" rx="1" fill="{WARM}"/>
  <rect x="25" y="31" width="4" height="4" rx="1" fill="{WARM}"/>
  <path d="M13 38 h22" stroke="{ALLOY}" stroke-width="2.4" stroke-linecap="round"/>""")

def ico_bar():
    return badge(f"""
  <rect x="17" y="8" width="14" height="32" rx="5" fill="{SNOW}"/>
  <rect x="20" y="11" width="8" height="14" rx="3" fill="{WARM}" opacity="0.9"/>
  <rect x="20" y="29" width="8" height="7" rx="2" fill="{ALLOY}"/>
  <circle cx="24" cy="5.5" r="1.8" fill="{AMBER}"/>
  <path d="M13 40 h22" stroke="{ALLOY}" stroke-width="2.4" stroke-linecap="round"/>""")

def ico_authority():
    return badge(f"""
  <path d="M24 8 L38 14 V26 C38 33 32 38 24 41 C16 38 10 33 10 26 V14 Z"
        fill="{ALLOY}" stroke="{SNOW}" stroke-width="2.4" stroke-linejoin="round"/>
  <circle cx="24" cy="23" r="5" fill="none" stroke="{CYAN}" stroke-width="2.4"/>
  <circle cx="24" cy="23" r="1.8" fill="{CYAN}"/>
  <path d="M24 15 v3 M24 28 v3 M16 23 h3 M29 23 h3" stroke="{AMBER}" stroke-width="2" stroke-linecap="round"/>""")

def ico_teleport():
    return badge(f"""
  <ellipse cx="24" cy="33" rx="15" ry="6" fill="{ALLOY}" stroke="{SNOW}" stroke-width="2.2"/>
  <ellipse cx="24" cy="31.4" rx="9" ry="3.4" fill="{CYAN}" opacity="0.85"/>
  <path d="M24 27 C20 22 20 16 24 11 M24 27 C28 22 28 16 24 11"
        fill="none" stroke="{CYAN}" stroke-width="2" stroke-linecap="round" opacity="0.8"/>
  <circle cx="24" cy="9" r="2.2" fill="{AMBER}"/>""")

BUILDINGS = {
    "authority": ico_authority, "bar": ico_bar, "cantine": ico_cantine,
    "elevator": ico_elevator, "factory": ico_factory, "farm": ico_farm,
    "farmarea": ico_farmarea, "kitchen": ico_kitchen, "living": ico_living,
    "maintenance": ico_maintenance, "mine": ico_mine, "mineshaft": ico_mineshaft,
    "oremine": ico_oremine, "oxygen": ico_oxygen, "quarter": ico_quarter,
    "solar": ico_solar, "storage": ico_storage, "teleport": ico_teleport,
}

# --------------------------------------------------- placement / warning ---
def p_check():
    return plain(f'<circle cx="24" cy="24" r="17" fill="none" stroke="{GREEN}" stroke-width="3"/>'
                 f'<path d="M16 24.5 l6 6 L34 18" fill="none" stroke="{GREEN}" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/>')

def p_invalid():
    return plain(f'<circle cx="24" cy="24" r="17" fill="none" stroke="{RED}" stroke-width="3"/>'
                 f'<path d="M17 17 L31 31 M31 17 L17 31" stroke="{RED}" stroke-width="3.4" stroke-linecap="round"/>')

def p_no_resource():
    return plain(f'<path d="M24 6 L39 15 V33 L24 42 L9 33 V15 Z" fill="none" stroke="{SNOW}" stroke-width="3"/>'
                 f'<path d="M15 15 L33 33" stroke="{RED}" stroke-width="3.4" stroke-linecap="round"/>'
                 f'<circle cx="24" cy="24" r="4" fill="{AMBER}"/>')

def p_bad_tile():
    return plain(f'<path d="M8 8 h32 v32 h-32 Z M19 8 v32 M30 8 v32 M8 19 h32 M8 30 h32" '
                 f'fill="none" stroke="{SNOW}" stroke-width="2.2"/>'
                 f'<path d="M11 11 L37 37" stroke="{RED}" stroke-width="3.4" stroke-linecap="round"/>')

def p_missing_link():
    return plain(f'<path d="M14 24 h5 M29 24 h5" stroke="{SNOW}" stroke-width="3" stroke-linecap="round"/>'
                 f'<circle cx="10" cy="24" r="4.5" fill="none" stroke="{SNOW}" stroke-width="2.6"/>'
                 f'<circle cx="38" cy="24" r="4.5" fill="none" stroke="{SNOW}" stroke-width="2.6"/>'
                 f'<path d="M21 20 L27 28 M27 20 L21 28" stroke="{RED}" stroke-width="2.6" stroke-linecap="round"/>')

def p_outside_dome():
    return plain(f'<path d="M6 34 A18 18 0 0 1 42 34" fill="none" stroke="{CYAN}" stroke-width="2.6"/>'
                 f'<path d="M6 34 h36" stroke="{SNOW}" stroke-width="2.2"/>'
                 f'<path d="M24 30 V14 M24 14 l-5 5 M24 14 l5 5" stroke="{RED}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" fill="none"/>')

def p_rotate():
    return plain(f'<path d="M36 24 a12 12 0 1 1 -4 -9" fill="none" stroke="{SNOW}" stroke-width="3.2" stroke-linecap="round"/>'
                 f'<path d="M33 8 l-1 8 l-8 -2" fill="none" stroke="{SNOW}" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>')

def p_entrance():
    return plain(f'<path d="M10 38 V10 h14 v28 Z" fill="none" stroke="{SNOW}" stroke-width="2.8" stroke-linejoin="round"/>'
                 f'<path d="M32 24 h-8 M24 24 l5 -5 M24 24 l5 5" fill="none" stroke="{AMBER}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>'
                 f'<path d="M36 18 l6 6 l-6 6" fill="none" stroke="{AMBER}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>')

def p_worker_radius():
    return plain(f'<circle cx="24" cy="24" r="15" fill="none" stroke="{AMBER}" stroke-width="2.4" stroke-dasharray="5 4"/>'
                 f'<circle cx="24" cy="24" r="4" fill="{AMBER}"/>')

def p_valid():
    return p_check()

def p_new_dome():
    return plain(f'<path d="M8 36 A16 16 0 0 1 40 36" fill="none" stroke="{CYAN}" stroke-width="2.8"/>'
                 f'<path d="M5 36 h38" stroke="{SNOW}" stroke-width="2.6" stroke-linecap="round"/>'
                 f'<path d="M24 18 v-8 M20 14 h8" stroke="{AMBER}" stroke-width="3" stroke-linecap="round"/>')

def p_no_energy():
    return plain(f'<path d="M27 6 L14 27 h8 L20 42 L34 21 h-8 Z" fill="{AMBER}" fill-opacity="0.25" stroke="{AMBER}" stroke-width="2.6" stroke-linejoin="round"/>'
                 f'<path d="M10 10 L38 38" stroke="{RED}" stroke-width="3.4" stroke-linecap="round"/>')

def p_low_oxygen():
    return plain(f'<circle cx="24" cy="24" r="14" fill="none" stroke="{CYAN}" stroke-width="2.8"/>'
                 f'<circle cx="24" cy="24" r="5" fill="{CYAN}" opacity="0.5"/>'
                 f'<path d="M10 10 L38 38" stroke="{RED}" stroke-width="3.4" stroke-linecap="round"/>')

def p_output_full():
    return plain(f'<rect x="10" y="20" width="28" height="18" rx="3" fill="none" stroke="{SNOW}" stroke-width="2.8"/>'
                 f'<path d="M24 16 V6 M19 11 l5 -5 l5 5" fill="none" stroke="{AMBER}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>')

def p_starving():
    return plain(f'<path d="M10 26 h28 a14 10 0 0 1 -28 0 Z" fill="{SNOW}" fill-opacity="0.9"/>'
                 f'<path d="M24 26 V12 M24 12 c-3 0 -5 -2 -5 -5 M24 12 c3 0 5 -2 5 -5" '
                 f'fill="none" stroke="{AMBER}" stroke-width="2.4" stroke-linecap="round"/>')

def p_under_attack():
    return plain(f'<path d="M24 6 L44 40 H4 Z" fill="{RED}" fill-opacity="0.2" stroke="{RED}" stroke-width="3" stroke-linejoin="round"/>'
                 f'<path d="M24 18 v10" stroke="{RED}" stroke-width="3.4" stroke-linecap="round"/>'
                 f'<circle cx="24" cy="34" r="2.2" fill="{RED}"/>')

PLACEMENT = {
    "valid": p_valid, "invalid": p_invalid, "no-resource": p_no_resource,
    "bad-tile": p_bad_tile, "missing-link": p_missing_link,
    "outside-dome": p_outside_dome, "rotate": p_rotate, "entrance": p_entrance,
    "worker-radius": p_worker_radius, "new-dome": p_new_dome,
    "no-energy": p_no_energy, "low-oxygen": p_low_oxygen,
    "output-full": p_output_full, "starving": p_starving,
    "under-attack": p_under_attack,
}

# ------------------------------------------------------------------ brand --
def logo_svg(size=512, monochrome=False, bg=False):
    """VOIDHOLD dome mark. Geometric dome outline + amber beacon + cyan strands."""
    dom = SNOW if monochrome else SNOW
    bez = "#FFFFFF" if monochrome else AMBER
    cy = "#FFFFFF" if monochrome else CYAN
    inner = f"""
  <path d="M8 34 A16 16 0 0 1 40 34" fill="none" stroke="{dom}" stroke-width="3.4" stroke-linecap="round"/>
  <path d="M13 34 A11 11 0 0 1 35 34 M18 34 A6 6 0 0 1 30 34" fill="none" stroke="{dom}" stroke-width="2.2" opacity="0.75"/>
  <path d="M4 34 h40" stroke="{dom}" stroke-width="3.4" stroke-linecap="round"/>
  <path d="M24 18 V13" stroke="{bez}" stroke-width="3" stroke-linecap="round"/>
  <circle cx="24" cy="10" r="2.6" fill="{bez}"/>
  <path d="M17 22 l-4 -3 M31 22 l4 -3" stroke="{cy}" stroke-width="2.2" stroke-linecap="round"/>
  <circle cx="11" cy="18" r="1.6" fill="{cy}"/>
  <circle cx="37" cy="18" r="1.6" fill="{cy}"/>"""
    if bg:
        return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <rect width="48" height="48" rx="10.5" fill="#141C24"/>
  <rect width="48" height="48" rx="10.5" fill="url(#g)"/>
  <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#1B2836"/><stop offset="1" stop-color="#0C141C"/>
  </linearGradient></defs>{inner}</svg>"""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">{inner}</svg>'

def adaptive_fg():
    return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">
  <g transform="translate(30 30)">
    <path d="M8 34 A16 16 0 0 1 40 34" fill="none" stroke="#E8EEF4" stroke-width="3.4" stroke-linecap="round"/>
    <path d="M4 34 h40" stroke="#E8EEF4" stroke-width="3.4" stroke-linecap="round"/>
    <path d="M24 18 V13" stroke="#FFB020" stroke-width="3" stroke-linecap="round"/>
    <circle cx="24" cy="10" r="2.6" fill="#FFB020"/>
    <path d="M17 22 l-4 -3 M31 22 l4 -3" stroke="#5FD4E8" stroke-width="2.2" stroke-linecap="round"/>
  </g></svg>"""

def adaptive_bg():
    return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108">
  <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#1B2836"/><stop offset="1" stop-color="#0C141C"/>
  </linearGradient></defs>
  <rect width="108" height="108" fill="url(#g)"/>
  <circle cx="20" cy="22" r="1" fill="#E8EEF4" opacity="0.7"/>
  <circle cx="86" cy="16" r="0.8" fill="#E8EEF4" opacity="0.6"/>
  <circle cx="70" cy="30" r="0.7" fill="#E8EEF4" opacity="0.5"/>
  <circle cx="30" cy="12" r="0.7" fill="#E8EEF4" opacity="0.5"/></svg>"""

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-base", default="/home/z/my-project/VOIDHOLD/mobile/assets")
    args = ap.parse_args()

    jobs = []
    for name, fn in RESOURCES.items():
        jobs.append((fn(), os.path.join(args.out_base, "ui", "icons", "resources", name)))
    for name, fn in BUILDINGS.items():
        jobs.append((fn(), os.path.join(args.out_base, "ui", "icons", "buildings", name)))
    for name, fn in PLACEMENT.items():
        jobs.append((fn(), os.path.join(args.out_base, "ui", "icons", "placement", name)))

    for svg, base in jobs:
        os.makedirs(os.path.dirname(base), exist_ok=True)
        with open(base + ".svg", "w") as f:
            f.write(svg)
        cairosvg.svg2png(bytestring=svg.encode(), write_to=base + "_512.png",
                         output_width=512, output_height=512)
        cairosvg.svg2png(bytestring=svg.encode(), write_to=base + "_48.png",
                         output_width=48, output_height=48)
    print(f"  wrote {len(jobs)} icon sets (svg + 512 + 48)")

    brand = os.path.join(args.out_base, "brand")
    os.makedirs(brand, exist_ok=True)
    with open(os.path.join(brand, "voidhold_logo.svg"), "w") as f:
        f.write(logo_svg())
    cairosvg.svg2png(bytestring=logo_svg().encode(),
                     write_to=os.path.join(brand, "voidhold_logo_512.png"),
                     output_width=512, output_height=512)
    cairosvg.svg2png(bytestring=logo_svg(monochrome=True).encode(),
                     write_to=os.path.join(brand, "voidhold_logo_mono_512.png"),
                     output_width=512, output_height=512)
    for s in (1024, 512, 192):
        cairosvg.svg2png(bytestring=logo_svg(bg=True).encode(),
                         write_to=os.path.join(brand, f"app_icon_{s}.png"),
                         output_width=s, output_height=s)
    cairosvg.svg2png(bytestring=adaptive_fg().encode(),
                     write_to=os.path.join(brand, "adaptive_fg_432.png"),
                     output_width=432, output_height=432)
    cairosvg.svg2png(bytestring=adaptive_bg().encode(),
                     write_to=os.path.join(brand, "adaptive_bg_432.png"),
                     output_width=432, output_height=432)
    print("  wrote brand set (logo svg/mono, app icons 1024/512/192, adaptive layers)")

if __name__ == "__main__":
    main()
