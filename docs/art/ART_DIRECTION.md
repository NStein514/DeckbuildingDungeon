# Internal art direction — Deckbound

Use Image Generator for card artwork, selected UI artwork, enemy illustrations, and artwork used in animations, as requested by the user. Use the Image Generator skill when available; otherwise use its image generation tool directly. Generate visual frames/assets with it and implement animation timing, compositing and reduced-motion behavior in Flutter. Current icons are explicitly labeled temporary interface placeholders, not final illustration substitutes. No unrelated stock imagery or unapproved production sources. Gameplay never waits for final art.

## Visual language

Painterly, stylized dark fantasy with strong silhouettes, visible brush texture, atmospheric perspective, and restrained magical illumination. The Ashen Crypt is an ancient funerary complex: weathered basalt, worn bronze, scorched cloth, carved circles, dying amber torches, desaturated blue crystal, drifting ash. Characters should feel specific and handmade rather than photorealistic or glossy.

Palette: charcoal #10151C, slate #1B2630, warm parchment #EBDFC5, aged bronze #C8A96B, ember #DF8E78, frost #8EBFC8, violet #BBA3DE, venom #A5B876. UI uses high-contrast text; hues never carry rules alone.

Light: one warm torch key, a subtle cool rim, and a dark readable background. Fire illuminates orange-red; ice is muted cyan; lightning is pale lavender; poison is olive-green. Keep saturated color local to the effect.

## Composition and continuity

Cards: 1024×768 landscape artwork, focal subject centered in the middle 70%, useful silhouette at 150px card width. Do not include names, numbers, rules text, typography, borders, watermarks, or card frames. Flutter renders all text and frames. Allow 10% crop margin; never bake UI into the art.

Enemies: 1024×1024 with transparent backgrounds, complete silhouettes and weapon tips inside the canvas. Repeat the same weapon, armor damage, and clothing in future poses. Warden: massive basalt funerary armor, cracked bronze faceplate, single amber eye, iron crypt hammer; no horned demon styling.

Backgrounds: 1440×2560 portrait, with quiet upper and lower zones for UI; provide a later landscape composition instead of stretching. Relics: 768×768 transparent, a single object with no shadow clipped at the edge. UI ornament: subtle and readable; do not replace standard accessibility indicators with decorative glyphs.

## Import and review

Review silhouette at phone size, palette, consistency, anatomy, cropping, transparency, and absence of accidental text. Retain approved source images outside the runtime bundle. Export optimized PNG/WebP with no gameplay text. Record approval and path in ASSET_MANIFEST.md. Add the path to the Flutter asset declarations and `AssetRegistry.illustrations`; the content logical ID remains stable. Never mark placeholder assets approved.
