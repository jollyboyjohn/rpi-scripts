#!/usr/bin/perl -w

# Do this to get information on a DVD:
#     mplayer -ao null -vo null -frames 0 dvd://

my %dvd;
my $wtitle;
my $wstereo;
my $wmulti;
my $cmd;

my %options = ( 
    DEINTERLACE => "deinterlace ! videoconvert !\\",
);

get_dvd_info();
#print_dvd_info();
my $audiostr = process_dvd_audio();

while(<DATA>) { 
    s/TITLENUM/$wtitle/g;
    s/VIDEOID/e0/g;
#    s/DEINTERLACE/$options{DEINTERLACE}/g;
    next if (/DEINTERLACE/);
    s/AUDIOOUTPUTS/$audiostr/g;
    $cmd .= $_;
}

print "Running command...\n";
#print $cmd;
exec "$cmd";
print "Command complete.\n";

#####################################

sub get_dvd_info {
    open LSDVD, "lsdvd -a |";
    my @lines=<LSDVD>;

    for(my $i = 0; $i <= $#lines; $i++) {
        if ($lines[$i] =~ /^Disc Title: (.*)$/) {
	    $dvd{name} = $1;
        }
        if ($lines[$i] =~ /^Longest track: (\d+)/) {
	    $dvd{longest} = $1;
        }
        if ($lines[$i] =~ /^Title: (\d+),.+? (\d+),.+? (\d+), .+? (\d+)/) {
	    my $curtitle = $1;
	    $dvd{titles}{$curtitle}{chapters} = $2;
	
	    if (exists($dvd{mostchap})) {
	        $dvd{mostchap} = $curtitle if ($dvd{titles}{$dvd{mostchap}}{chapters} < $2);
	    } else {
	        $dvd{mostchap} = $curtitle;
	    }

	    for (1..$4) {
	        $lines[++$i] =~ /^\s+?Audio: (\d+),.+?age: (..) -.+?mat: (.+?),.+?nels: (\d),.+?: 0x(\w\w)$/;
	        $dvd{titles}{$curtitle}{audio}{$1}{lang} = $2;
	        $dvd{titles}{$curtitle}{audio}{$1}{type} = $3;
	        $dvd{titles}{$curtitle}{audio}{$1}{chan} = $4;
	        $dvd{titles}{$curtitle}{audio}{$1}{id} = $5;
	    }
        }
    }	
}

sub print_dvd_info {
    printf "Disc: %s\n", $dvd{name};
    foreach my $t (sort keys %{$dvd{titles}}) {
        printf "Title: %d, Chapters: %d\n", $t, $dvd{titles}{$t}{chapters};
        foreach my $a (sort keys %{$dvd{titles}{$t}{audio}}) {
	    printf "\tTrack: %d - Lang: %s, Type: %s, Chan: %d, Id: 0x%s\n",
	        $a,
	        $dvd{titles}{$t}{audio}{$a}{lang},
	        $dvd{titles}{$t}{audio}{$a}{type},
	        $dvd{titles}{$t}{audio}{$a}{chan},
	        $dvd{titles}{$t}{audio}{$a}{id};
        }
    }
}

sub process_dvd_audio {
    my $str;
    if ($dvd{longest} == $dvd{mostchap}) { 
        $wtitle = $dvd{longest};
        foreach my $a (sort keys %{$dvd{titles}{$wtitle}{audio}}) {
	    if (($dvd{titles}{$wtitle}{audio}{$a}{lang} eq "en") &&
	        ($dvd{titles}{$wtitle}{audio}{$a}{chan} == 6)) {
	        $wmulti = $a;
	        last;
	    }
	    if (($dvd{titles}{$wtitle}{audio}{$a}{lang} eq "en") &&
	        ($dvd{titles}{$wtitle}{audio}{$a}{chan} == 2)) {
	        $wstereo = $a;
	        last;
	    }
        }
    }

    if (defined($wstereo) && defined($wmulti)) {
        if (hex($wstereo) > hex($wmulti)) {
	    $str = audio_clone($wtitle,
	        $dvd{titles}{$wtitle}{audio}{$wmulti}{id}, 
	        $dvd{titles}{$wtitle}{audio}{$wmulti}{type});
        } else {
	    $str = audio_dual($wtitle,
	        $dvd{titles}{$wtitle}{audio}{$wstereo}{id}, 
	        $dvd{titles}{$wtitle}{audio}{$wstereo}{type},
	        $dvd{titles}{$wtitle}{audio}{$wmulti}{id},
	        $dvd{titles}{$wtitle}{audio}{$wmulti}{type});
        }
    } elsif (defined($wstereo)) {
        $str = audio_stereo($wtitle,
	    $dvd{titles}{$wtitle}{audio}{$wstereo}{id}, 
	    $dvd{titles}{$wtitle}{audio}{$wstereo}{type});
    } else {
        $str = audio_clone($wtitle,
	    $dvd{titles}{$wtitle}{audio}{$wmulti}{id}, 
	    $dvd{titles}{$wtitle}{audio}{$wmulti}{type});
    }
    return $str;
}

sub audio_stereo {
    my ($title, $aid, $type) = @_;
    my $temp = "    demux.audio_AUDIOID !\\
        queue max-size-bytes=0 max-size-buffers=0 max-size-time=5000000000 !\\
	AUDIODECODE
	audioconvert dithering=0 !\\
	audio/x-raw,channels=2 !\\
	faac !\\
	aacparse !\\
	audio/mpeg,mpegversion=4,channels=2 !\\
	queue !\\
        mux.audio_01 \\";
    $temp =~ s/AUDIOID/$aid/;
    if ($type eq "lpcm") {
	print "AUDIO: 2.0 LPCM => 2.0 AAC\n";
	$temp =~ s/AUDIODECODE/dvdlpcmdec !\\/;
    } elsif ($type eq "ac3") {
	print "AUDIO: 2.0 AC3 => 2.0 AAC\n";
	$temp =~ s/AUDIODECODE/ac3parse ! a52dec !\\/;
    } else {
	exit;
    }
    return $temp;
}

sub audio_clone {
    my ($title, $aid, $type) = @_;
    my $temp = "    demux.audio_AUDIOID !\\
        queue max-size-bytes=0 max-size-buffers=0 max-size-time=5000000000 !\\
	AUDIODECODE1
	tee name=dup !\\
	    AUDIODECODE2
	    audioconvert dithering=0 !\\
	    audio/x-raw,channels=2 !\\
	    faac !\\
	    aacparse !\\
	    audio/mpeg,mpegversion=4,channels=2 !\\
	    queue !\\
            mux.audio_01 \\
	dup. !\\
	    AUDIOENCODE
            mux.audio_02 \\";
    $temp =~ s/AUDIOID/$aid/;
    if ($type eq "lpcm") {
	print "AUDIO: 5.1 LPCM => 5.1 AC3 + 2.0 AAC\n";
	$temp =~ s/AUDIODECODE1/dvdlpcmdec !\\/;
	$temp =~ s/AUDIODECODE2/queue !\\/;
	$temp =~ s/AUDIOENCODE/avenc_ac3 bitrate=192000 ! audio\/x-ac3,channels=6 ! queue !\\/;
    } elsif ($type eq "ac3") {
	print "AUDIO: 5.1 AC3 => 5.1 AC3 (passthru) + 2.0 AAC\n";
	$temp =~ s/AUDIODECODE1/ac3parse ! audio\/x-ac3,channels=6 ! \\/;
	$temp =~ s/AUDIODECODE2/a52dec !\\/;
	$temp =~ s/AUDIOENCODE/queue !\\/;
    } else {
	exit;
    }
    return $temp;
}

sub audio_dual {
    my ($title, $aid1, $type1, $aid2, $type2) = @_;
    my $temp = "    demux.audio_AUDIOID1 !\\
	    AUDIODECODE1
	    audio/x-raw,channels=2 !\\
	    faac !\\
	    aacparse !\\
	    audio/mpeg,mpegversion=4,channels=2 !\\
	    queue !\\
            mux.audio_00 \\
	demux.audio_AUDIOID2 !\\
	    AUDIODECODE2
	    queue !\\
            mux.audio_01 \\";
    $temp =~ s/AUDIOID1/$aid1/;
    $temp =~ s/AUDIOID2/$aid2/;
    if ($type1 eq "lpcm") {
	print "AUDIO: 2.0 LPCM => 2.0 AAC, ";
	$temp =~ s/AUDIODECODE1/dvdlpcmdec !\\/;
    } elsif ($type1 eq "ac3") {
	print "AUDIO: 2.0 AC3 => 2.0 AAC, ";
	$temp =~ s/AUDIODECODE1/ac3parse ! a52dec !\\/;
    } else {
	exit;
    }
    if ($type2 eq "lpcm") {
	print "5.1 LPCM => 5.1 AC3\n";
	$temp =~ s/AUDIODECODE2/dvdlpcmdec ! avenc_ac3 bitrate=192000 ! audio\/x-ac3,channels=6 !\\/;
    } elsif ($type2 eq "ac3") {
	print "5.1 AC3 => 5.1 AC3 (passthru)\n";
	$temp =~ s/AUDIODECODE2/ac3parse ! audio\/x-ac3,channels=6 !\\/;
    } else {
	exit;
    }
    return $temp;
}

__DATA__
gst-launch-1.0 -e \
    dvdreadsrc title=TITLENUM device=/dev/cdrom !\
    queue max-size-bytes=0 max-size-buffers=0 max-size-time=5000000000 !\
    mpegpsdemux name=demux \
    demux.video_VIDEOID !\
	progressreport !\
        queue max-size-bytes=0 max-size-buffers=0 max-size-time=5000000000 !\
	mpegvideoparse !\
	mpeg2dec !\
	queue !\
	videocrop top=82 left=0 right=0 bottom=78 !\
	DEINTERLACE
	videoconvert !\
	omxh264enc target-bitrate=1500000 control-rate=1 inline-header=true periodicty-idr=250 interval-intraframes=250 !\
	h264parse config-interval=1 !\
	video/x-h264,stream-profile=avc,alignment=au,profile=high !\
	queue !\
        mux.video_00 \
AUDIOOUTPUTS
    avimux name=mux !\
	filesink location=/mnt/temp/test.avi
