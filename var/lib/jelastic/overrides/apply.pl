#!/usr/bin/perl

#use strict;
use Template;
use Data::Dumper;
use Config::IniFiles;
my $cfg = Config::IniFiles->new( -file => "/etc/jelastic/settings.conf" );
my ($src, $dest) = @ARGV;
#print $#ARGV;

unless(defined ($src)) {
    print "Template not defined\n";
    exit 1;
}

unless(defined ($dest)) {
    print "Dest not defined\n";
    exit 2;
}

unless (-e $src) {
     print "Template File not Exists!\n";
     exit 3;
}

@params=$cfg->Parameters('require');
my %dataHash= ();
foreach my $p ( @params) {
    my $pVal = $cfg->val('require', $p);
    my $tmpVal = $p;
    $tmpVal =~ s/\//_/g;
    $$tmpVal=$cfg->val('require', $p);
    if ( $pVal =~ /;/ ) {
	   my @tmpArr = split /;/, $pVal ;
	   $dataHash{$tmpVal}=\@tmpArr;
    }else {
        $dataHash{$tmpVal}=$cfg->val('require', $p);
    }
}

$dataHash{'jelastic_internalip_local'} = $ENV{'internalIp'} if ( defined ($ENV{'internalIp'}) ) ;
$dataHash{'jelastic_externalip_local'} = $ENV{'externalIp'} if ( defined ($ENV{'externalIp'}) ) ;

my @ip_ar = split ( /\./, $ENV{'internalIp'}, 5 );
$dataHash{'jelastic_internalip_local_reverse'} = "$ip_ar[2].$ip_ar[1].$ip_ar[0]";
#print Dumper(%dataHash);
my $parser = Template->new (INCLUDE_PATH => '/etc/jelastic/erb', POST_CHOMP => 0, ABSOLUTE => 1, DEBUG => 1, EVAL_PERL => 1, START_TAG => '<%=', END_TAG => '%>' );
$parser->process($src, \%dataHash, $dest )  or die $parser->error;
