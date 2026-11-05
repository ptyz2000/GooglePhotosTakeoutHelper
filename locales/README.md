# Languages 🌍

Google Takeout names some folders and files after the language of your Google account. Every file here teaches `gpth` the names for one language, and **anyone can add one - no programming needed.**

`gpth` uses all of them at once, so people never have to tell it which language their Takeout is in.

## What's needed

| Key | What it is |
| --- | --- |
| `name` | Name of the language, in English (`"German"`) |
| `credits` | Your GitHub `@username`, so you get the credit 💖 |
| `yearFolders` | Names of the year folders, with `{year}` instead of the year. English is `"Photos from {year}"` |
| `editedSuffixes` | What Google adds to the names of edited photos. English is `"-edited"` |

You don't have to fill everything in - a file with just one of them still helps. Languages that have no `yearFolders` yet are the ones that need your help the most!

## How to find the names

1. **Year folders:** open your Takeout, go to `Takeout/Google Photos/` and look at the folders that are named after a year. Copy the name, and replace the year with `{year}`. If one is called `Fotos von 2021`, write `"Fotos von {year}"`. Add all the variants you see, if there are more than one
2. **Edited photos:** in Google Photos, edit a photo and save it as a copy, then export again. Look at the file name next to the original: `IMG_1234.jpg` and `IMG_1234-edited.jpg`. The part that was added (with the dash) is the suffix in your language

## How to add a language

1. Copy [`_template.json`](_template.json) to `<language code>.json` - for example `de.json`, or `pt-BR.json` if the region matters
2. Fill it in
3. Open a pull request

   If you have Dart installed, also run these two from the root of the project, which checks your file and updates the file that gets compiled into `gpth`:
   ```bash
   dart run scripts/gen_locales.dart
   dart test
   ```
   If you don't - no problem! Open the pull request with only your JSON file. The "up to date" check will fail, and a maintainer will run the command for you.

**Can't do any of that?** [Open an issue](https://github.com/TheLastGimbus/GooglePhotosTakeoutHelper/issues/new?template=new-language.md) and paste the names - someone will add them for you.

## Good to know

- Names are matched exactly (the year folders) or at the end of the file name (the suffixes). Capital letters in suffixes don't matter
- Please only add names that you have seen in a real Takeout
- Files starting with `_` are ignored, so [`_template.json`](_template.json) isn't a language
- Want to try something without sending it to us? Use it privately with `gpth --locale-file my-file.json`
