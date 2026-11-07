# A-01 monitor asset

Source: computer.glb supplied by the team and downscaled locally for the Godot build.
Format: GLB 2.0, 1 mesh, 1 material, 50,000 triangles, 3 embedded 1024px PNG textures.
Godot-side correction: keep authored rotation (Y=0), scale 1.0, move base to the procedural desktop.
Original source is retained outside the repository; this copy is the game-ready reduced-texture version.
The imported scene already places its base at Y=0; the instance sits at desktop Y=1.02. Dynamic audit text stays on a separate desk-front plaque so it is not occluded by the model.

## Additional desk props
- Keyboard, file and stamp are project copies of team-provided keyboard.glb, file.glb and 印章.glb in the download folder. Originals were not overwritten.
- Each retains 50,000 triangles and its authored node transform; embedded PNGs are resized to 512px for small tabletop use. Resulting GLBs are about 2.08 / 1.88 / 1.77 MB.
- Existing animated hunter v3 and monitor were already integrated; older versions of the same hunter are intentionally not duplicated.
- Godot instance transforms place model bases at tabletop Y=1.02. Props are decorative only, without added gameplay collision.
