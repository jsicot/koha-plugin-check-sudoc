package Koha::Plugin::Fr::UnivRennes2::CheckSudoc::Sudoc;

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This program comes with ABSOLUTELY NO WARRANTY;

use Modern::Perl;
use LWP::Simple qw( $ua get );
$ua->proxy( 'https', 'http://wwwcache.univ-rennes2.fr:8080' );
use JSON;     # From CPAN
use utf8;  
use Data::Dumper;               # Perl core module
use strict;                     # Good practice
use warnings;                   # Good practice


#------------------------------------------------------------------------------
sub mwhere {
	my ( $self, $ppn ) = @_;
	my $iln = "59";
	##my @rcrFromIln = &getRcrFromIln($iln);
	my @rcrFromIln = split(/\|/, $self->retrieve_data('rcr'));
	my @rcrFromPpn = &getRcrFromPpn($ppn);
	
	if ($rcrFromPpn[0] eq "null"){
		  return "null\n";
	}
    elsif ($rcrFromPpn[0] eq "error") {
         return "error\n";
   }
	else {
		my @loc;
		 foreach my $element (@rcrFromPpn) {
			  my %elements;
			  foreach (@rcrFromIln) {
			    $elements{$_} = 1;
			  };
			  push (@loc, $element ) if (exists $elements{$element});
		 }
		 if (scalar @loc != 0){
			 return @loc;
		 }
		 else {
			 return "false";
		 }
	}
}
#------------------------------------------------------------------------------
sub isMerged {
  	my ( $self, $ppn ) = @_;
  	chomp($ppn);
  	my $mergedws = "https://www.sudoc.fr/services/merged/";
	my @ppnMerged;
	my $svc = &construct_svc($ppn,$mergedws);
	my $json = get( $svc );
#	die "Could not get $svc!" unless defined $json;	
    if ($json) {

        # Decode the entire JSON
	    #print 'is_utf8: ' . ( utf8::is_utf8( $json ) ? 'yes' : 'no' ) . "\n"; 
    	my $decoded = utf8::is_utf8( $json )
	    ? from_json( $json )
	    : decode_json( $json );
	
	    #print Dumper $decoded;
	
	    if($decoded->{'sudoc'}{'query'}{'result'} ){
		    if(ref($decoded->{'sudoc'}{'query'}{'result'}{'ppn'}) eq 'ARRAY') {
			    my @results = @{ $decoded->{'sudoc'}{'query'}{'result'}{'library'} };
			    foreach my $r ( @results  ) {
				    print my $ppnMerged = "$r->{'ppn'}"; 
				    push (@ppnMerged, $ppnMerged );
			    }
		    }
		    else { 
		 	    push (@ppnMerged, $decoded->{'sudoc'}{'query'}{'result'}{'ppn'}); 
		    }
		    return @ppnMerged;
	    }
	    else { return "null";}
    } else { return "error" ;}	
}
#------------------------------------------------------------------------------
sub getRcrFromPpn {
  	my ( $self, $ppn ) = @_;
  	chomp($ppn);
  	#$ppn = "001593692";
  	my $multiwhere = "https://www.sudoc.fr/services/multiwhere/";
	my @rcr;
	my $svc = &construct_svc($ppn,$multiwhere);
	my $json = get( $svc );
	#die "Could not get $svc!" unless defined $json;	
	if ($json) {
        # Decode the entire JSON
	    #print 'is_utf8: ' . ( utf8::is_utf8( $json ) ? 'yes' : 'no' ) . "\n"; 
	    my $decoded = utf8::is_utf8( $json )
	    ? from_json( $json )
	    : decode_json( $json );
		
	    if($decoded->{'sudoc'}{'query'}{'result'}{'library'} && !$decoded->{'sudoc'}{'error'}){
		    if(ref($decoded->{'sudoc'}{'query'}{'result'}{'library'}) eq 'ARRAY') {
			    my (@results) = @{ $decoded->{'sudoc'}{'query'}{'result'}{'library'} };
			    foreach my $r ( @results  ) {
				     push ( @rcr, $r->{'rcr'} ) unless (ref($r->{'rcr'}) eq 'ARRAY');
		    	}
		    } else { 
		 	    push (@rcr, $decoded->{'sudoc'}{'query'}{'result'}{'library'}{'rcr'}); 
		     }

			
		    return @rcr;
	    }
	    else { return "null";}
    } else { return "error";}   
		
}
#------------------------------------------------------------------------------
sub getRcrFromIln {
  	my ( $self, $iln ) = @_;
  	chomp($iln);
  	my $iln2rcr = "https://www.idref.fr/services/iln2rcr/";
	my @rcr;
	my $svc = &construct_svc($iln,$iln2rcr);
	my $json = get( $svc );
	#die "Could not get $svc!" unless defined $json;	
    if ($json) { 
        # Decode the entire JSON
	    print 'is_utf8: ' . ( utf8::is_utf8( $json ) ? 'yes' : 'no' ) . "\n"; 
    	my $decoded = utf8::is_utf8( $json )
    	? from_json( $json )
	    : decode_json( $json );
	
# 	    print Dumper $decoded;

	    if($decoded->{'sudoc'}{'query'}{'result'} && !$decoded->{'sudoc'}{'error'}){
		    my @results = @{ $decoded->{'sudoc'}{'query'}{'result'} };
		    foreach my $r ( @results  ) {
			     my $rcr = "$r->{'library'}{'rcr'}"; 
			     push (@rcr, $rcr );
	    	}
	    }
	    return @rcr;
    }
    else { return "error";}
}
#------------------------------------------------------------------------------
sub construct_svc {
  my ($value, $url) = @_;
  chomp($url);
  my $svc = "$url$value&format=text/json\n" ;
  return $svc;
}
1;
