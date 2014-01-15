images
=====

Basic photos organizer. Uses EXIF data or filename for figuring out essential photo information, Perl 5.10 or higher with modules `Digest::MD5` and `File::Path`.

Help is shown when run with "--help" switch:

```
$ ./images.pl --help
./images.pl version 1.0 calling Getopt::Std::getopts (version 1.06),
running under Perl version 5.14.2.
Usage:
  ./images.pl [options]

Options:
  -i  input directory (default '/home/qalex/git/images')
  -o  output directory (default '/home/qalex/Pictures/original/')
  -t  somehow separated list of file extensions to process
        (default 'jpg', 'jpeg', 'png', 'cr2', 'nef')
  -c  camera string to use when no camera is available in EXIF data (no default)
  -f  force action (do something actually)
  -m  move files (default is simply "ln")
  -v  be verbose (is on if no -f option supplied)

Example:
  ./images.pl -i . -o ~/images/ -c 'coolpix 15d' -t nef,jpg -m
Process images in current directory to $HOME/images/, using 'coolpix 15d' as camera string
when no camera is saved in EXIF data, processing *.nef and *.jpg files. Move, but actually do
nothing (print string to be executed if -f option is added)
```

Example

```
% tree 1
1
├── IMG_3660.CR2
├── IMG_3661.CR2
├── IMG_3662.CR2
├── IMG_3663.CR2
├── IMG_3664.CR2
├── IMG_3665.CR2
├── IMG_3666.CR2
├── IMG_3667.CR2
├── IMG_3668.CR2
└── IMG_3669.CR2


% ~/bin/images.pl -i 1 -o 2 -m -v -f
Searching in '1'
Target directory '2'
Filetypes to be processed: jpg jpeg png cr2 nef
Will actually do stuff, action 'mv'. Continue? (y/n) y
mv "1/IMG_3663.CR2" "2/Canon EOS 5D Mark II/2013/07/20130705T214743.CR2"
mv "1/IMG_3669.CR2" "2/Canon EOS 5D Mark II/2013/07/20130705T214855.CR2"
mv "1/IMG_3660.CR2" "2/Canon EOS 5D Mark II/2013/07/20130705T214438.CR2"
mv "1/IMG_3665.CR2" "2/Canon EOS 5D Mark II/2013/07/20130705T214820.CR2"
mv "1/IMG_3662.CR2" "2/Canon EOS 5D Mark II/2013/07/20130705T214727.CR2"
mv "1/IMG_3664.CR2" "2/Canon EOS 5D Mark II/2013/07/20130705T214757.CR2"
mv "1/IMG_3668.CR2" "2/Canon EOS 5D Mark II/2013/07/20130705T214854.CR2"
mv "1/IMG_3661.CR2" "2/Canon EOS 5D Mark II/2013/07/20130705T214718.CR2"
mv "1/IMG_3667.CR2" "2/Canon EOS 5D Mark II/2013/07/20130705T214844.CR2"
mv "1/IMG_3666.CR2" "2/Canon EOS 5D Mark II/2013/07/20130705T214836.CR2"

% tree 2
2
└── Canon EOS 5D Mark II
    └── 2013
        └── 07
            ├── 20130705T214438.CR2
            ├── 20130705T214718.CR2
            ├── 20130705T214727.CR2
            ├── 20130705T214743.CR2
            ├── 20130705T214757.CR2
            ├── 20130705T214820.CR2
            ├── 20130705T214836.CR2
            ├── 20130705T214844.CR2
            ├── 20130705T214854.CR2
            └── 20130705T214855.CR2

3 directories, 10 files
```
