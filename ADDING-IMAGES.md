# Adding New Puzzle Images

## Quick Start

```bash
cd puzzle-app
./scripts/add-images.sh ~/Photos/panda.jpg ~/Downloads/kitten.png
```

That's it. Rebuild in Xcode and the new images will appear in the game.

## What the Script Does

- Finds the next available `animal_N` index automatically
- Creates the `.imageset` folder structure in the iOS asset catalog
- Copies your image and generates the required `Contents.json`
- No code changes needed — the app detects new images at runtime

## Image Requirements

**Format:** JPG, PNG, HEIC, WebP, GIF, BMP, TIFF — all accepted.

**Size:** Any resolution works. The app loads whatever you give it. Something in the 800–2000px range is ideal for memory efficiency, but larger images won't cause problems.

**Aspect ratio:** Doesn't matter. The app automatically center-crops every image to 4:3 (landscape) at runtime. You can drop in portraits, squares, panoramas — they'll all look fine.

## Where Images Live

```
ios/KaleysPuzzle/Assets.xcassets/user-uploaded-pictures/
├── animal_1.imageset/
│   ├── animal_1.jpg
│   └── Contents.json
├── animal_2.imageset/
│   ├── animal_2.png
│   └── Contents.json
└── ...
```

## Adding Images Manually (Without the Script)

1. Create a folder: `ios/KaleysPuzzle/Assets.xcassets/user-uploaded-pictures/animal_N.imageset/`
2. Copy your image into it (any name works)
3. Create `Contents.json` in the same folder:

```json
{
  "images" : [
    {
      "filename" : "your-image.jpg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

4. Rebuild in Xcode

**Important:** Indices must be sequential starting from 1 with no gaps. If you have `animal_1` through `animal_20`, the next one must be `animal_21`.

## Tips

- Landscape photos look best (they match the 4:3 puzzle grid naturally with minimal cropping)
- The subject should be roughly centered since the crop is from the center
- High-contrast, colorful images make for better puzzles (easier to distinguish pieces)
