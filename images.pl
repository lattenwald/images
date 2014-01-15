#!/usr/bin/env perl
use strict;
use warnings;
use autodie;

use Carp;
use Cwd;
use Digest::MD5;
use File::Basename;
use File::Find;
use File::Path qw/make_path/;
use Getopt::Std;
use IPC::Open3;
use Symbol qw/gensym/;

use constant DIR_TO   => "$ENV{HOME}/Pictures/original";
use constant DIR_FROM => getcwd();
use constant ACTION   => [qw/ln/];
use constant EXTS     => [qw/jpg jpeg png cr2 nef/];

my ($dir_from, $dir_to, @action, @extensions, $verbose, $default_camera, $force);

our $VERSION = '1.0';
$Getopt::Std::STANDARD_HELP_VERSION = 1;

init();
main();


sub init {
	$dir_from = DIR_FROM;
	$dir_to = DIR_TO;
	@action = @{ACTION()};
	@extensions = @{EXTS()};

	my %opts;
	unless(getopts('i:o:t:c:fmv', \%opts)) {
		usage();
		exit 1;
	}

	$verbose = $opts{v};

	if ($opts{i}) {
		$dir_from = $opts{i};
		unless (-d $dir_from) {
			print STDERR 'Wrong input directory', "\n";
			exit 1;
		}
	}
	print STDERR "Searching in '$dir_from'\n";

	if ($opts{o}) {
		$dir_to = $opts{o};
		$dir_to =~ s|(?<=.)/+$||;
		unless (-d $dir_to) {
			print STDERR 'Wrong output directory', "\n";
			exit 1;
		}
	}
	print STDERR "Target directory '$dir_to'\n";

	if ($opts{t}) {
		@extensions = split /\W+/, $opts{t};
	}
	print STDERR "Filetypes to be processed: @extensions\n";

	if ($opts{c}) {
		$default_camera = $opts{c};
		unless ($default_camera =~ /^\w(?:[\w\- ]*\w)?$/) {
			print STDERR "Invalid default camera\n";
			exit 1;
		}
		print STDERR "Will use '$default_camera' as default camera\n";
	}

	if ($opts{m}) {
		@action = ('mv');
	}
	if ($opts{f}) {
		$force = 1;

		{
			local $| = 1;
			print STDERR "Will actually do stuff, action '@action'. Continue? (y/n) ";
		}

		my $input = <STDIN>;
		unless ($input =~ /^y(?:es)?$/i) {
			print STDERR "Exiting\n";
			exit;
		}
	} else {
		$verbose = 1;
	}
}

sub main {
	my $ext_re = '\.(' . join('|', @extensions) . ')$';
	my $exclude_re = qr|/\.\w|;

	my $wanted = sub {
		# $File::Find::dir is the current directory name,
		# $File::Find::name is the complete pathname to the file.
		# $_ is the same (as no_chdir was supplied)
		return unless my ($ext) = /$ext_re/i;
		return if $_ =~ $exclude_re;
		my $pid = open3(gensym, my $F, gensym, 'exiv2', '--', $_);

		my ($camera, $date_dir, $date_fn);
		while (my $line = <$F>) {
			if ($line =~ /^Camera model\s+:\s+(.+?)\s*$/) {
				$camera = $1;
				next;
			}
			if ($line =~ /Image timestamp : (\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$/) {
				$date_dir = "$1/$2";
				$date_fn = "$1$2$3T$4$5$6";
				next;
			}
		}
		waitpid $pid, 0;
		# close $F;
		$camera ||= $default_camera;
		unless ($camera) {
			print "Skipping file '$_': empty camera\n";
			return;
		}

		if (not($date_fn) and /^(?:(?:IMG|PANO)_)?(\d{4})(\d\d)(\d\d)[_T](\d\d)(\d\d)(\d\d)[._]/) {
			$date_dir = "$1/$2";
			$date_fn = "$1$2$3T$4$5$6";
		}

		if (not($date_fn) and /^((\d{4})(\d\d)(\d\d)_\w+)\./) {
			$date_dir = "$2/$3";
			$date_fn = $1;
		}

		unless ($date_fn) {
			$date_fn = basename($_);
			$date_dir = 'NO DATE';
			print "exif data for '$_' have no date data\n";
		}

		my $dn = $dir_to . "/$camera/$date_dir";
		make_path($dn) if $force;
		my $nonce = '';
		my $i = 0;
		my ($file_to, $checksum);
		while (-e ($file_to = "$dn/$date_fn$nonce.$ext")) {
			return if $_ eq $file_to;
			unless ($checksum) {
				open my $fh, '<', $_ or croak "Failed opening file '$_': $!";
				binmode $fh;
				$checksum = Digest::MD5->new->addfile($fh)->hexdigest;
				close $fh or croak "Failed opening file '$_': $!";
			}

			open my $fh, '<', $file_to or croak "Failed opening file '$file_to': $!";
			binmode $fh;
			my $checksum_to = Digest::MD5->new->addfile($fh)->hexdigest;
			close $fh or croak "Failed opening file '$file_to': $!";

			if ($checksum eq $checksum_to) {
				print STDERR "Deduplication service reports: '$_' and '$file_to' are the same\n";
				last;
			}

			$nonce = '_' . ++$i;
		}
		if ($verbose) {
			print join(' ', @action, '"' . $_ . '"', '"' . $file_to . '"'), "\n";
		}
		if ($force) {
			system @action, $_, $file_to;
		}
	};

	find({no_chdir => 1, wanted => $wanted}, $dir_from);
}

sub usage {
	my $usage = sprintf <<"USAGE", DIR_FROM, DIR_TO, join(', ', map +"'$_'", @{EXTS()});
Usage:
  $0 [options]

Options:
  -i  input directory (default '%s')
  -o  output directory (default '%s')
  -t  somehow separated list of file extensions to process
        (default %s)
  -c  camera string to use when no camera is available in EXIF data (no default)
  -f  force action (do something actually)
  -m  move files (default is simply "ln")
  -v  be verbose (is on if no -f option supplied)

Example:
  $0 -i . -o ~/images/ -c 'coolpix 15d' -t nef,jpg -m
Process images in current directory to \$HOME/images/, using 'coolpix 15d' as camera string
when no camera is saved in EXIF data, processing *.nef and *.jpg files. Move, but actually do
nothing (print string to be executed if -f option is added)
USAGE

	print STDERR $usage;
}

sub HELP_MESSAGE() {usage()}

######### Nikon d70s
# $ exiv2 20060601_050251.nef
# File name       : 20060601_050251.nef
# File size       : 5794839 Bytes
# MIME type       : image/x-nikon-nef
# Image size      : 3040 x 2014
# Camera make     : NIKON CORPORATION
# Camera model    : NIKON D70s
# Image timestamp : 2006:06:01 05:02:51
# Image number    :
# Exposure time   : 1/30 s
# Aperture        : F3.8
# Exposure bias   : 0 EV
# Flash           : No flash
# Flash bias      :
# Focal length    : 22.0 mm (35 mm equivalent: 33.0 mm)
# Subject distance:
# ISO speed       : 800
# Exposure mode   : Aperture priority
# Metering mode   : Multi-segment
# Macro mode      :
# Image quality   : RAW
# Exif Resolution : 160 x 120
# White balance   : CLOUDY
# Thumbnail       : None
# Copyright       :
# Exif comment    :

########### Nikon Coolpix S500
# $ exiv2 20121120T144256.JPG
# File name       : 20121120T144256.JPG
# File size       : 906258 Bytes
# MIME type       : image/jpeg
# Image size      : 3072 x 2304
# Camera make     : NIKON
# Camera model    : COOLPIX S500
# Image timestamp : 2012:11:20 14:42:56
# Image number    :
# Exposure time   : 1 s
# Aperture        : F2.8
# Exposure bias   : 0 EV
# Flash           : No, compulsory
# Flash bias      :
# Focal length    : 5.7 mm (35 mm equivalent: 35.0 mm)
# Subject distance:
# ISO speed       : 50
# Exposure mode   : Auto
# Metering mode   : Multi-segment
# Macro mode      :
# Image quality   : NORMAL
# Exif Resolution : 3072 x 2304
# White balance   : AUTO
# Thumbnail       : image/jpeg, 4176 Bytes
# Copyright       :
# Exif comment    :

######### Nokia N900
# $ exiv2 20121120T144256.JPG
# File name       : 20121120T144256.JPG
# File size       : 906258 Bytes
# MIME type       : image/jpeg
# Image size      : 3072 x 2304
# Camera make     : NIKON
# Camera model    : COOLPIX S500
# Image timestamp : 2012:11:20 14:42:56
# Image number    :
# Exposure time   : 1 s
# Aperture        : F2.8
# Exposure bias   : 0 EV
# Flash           : No, compulsory
# Flash bias      :
# Focal length    : 5.7 mm (35 mm equivalent: 35.0 mm)
# Subject distance:
# ISO speed       : 50
# Exposure mode   : Auto
# Metering mode   : Multi-segment
# Macro mode      :
# Image quality   : NORMAL
# Exif Resolution : 3072 x 2304
# White balance   : AUTO
# Thumbnail       : image/jpeg, 4176 Bytes
# Copyright       :
# Exif comment    :
