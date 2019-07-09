package Koha::Plugin::Fr::UnivRennes2::CheckSudoc;

use Modern::Perl;
use base qw(Koha::Plugins::Base);
use Mojo::JSON qw(decode_json);
use utf8;
use Data::Dumper; 
use CGI;
use Koha::DateUtils;
use Koha::Plugin::Fr::UnivRennes2::CheckSudoc::Sudoc;

my $sudoc ='Koha::Plugin::Fr::UnivRennes2::CheckSudoc::Sudoc';

## Here we set our plugin version
our $VERSION = '{VERSION}';

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Check Sudoc',
    author          => 'Julien Sicot',
    date_authored   => '2019-07-09',
    date_updated    => '{UPDATE_DATE}',
    minimum_version => '18.110000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin uses micro webservices from SUDOC (Abes) to add some controls and alerts on records in the staff interface (check holdings sync with the sudoc, merged or duplicate or local records detection, etc).',
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

## If your tool is complicated enough to needs it's own setting/configuration
## you will want to add a 'configure' method to your plugin like so.
## Here I am throwing all the logic into the 'configure' method, but it could
## be split up like the 'report' method is.
sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};
    
    my $template = $self->get_template({ file => 'configure.tt' });

    if ( $cgi->param('save') ) {
	    my $myconf;
	    
	    $myconf->{iln} = $cgi->param('iln');
	    
		if (defined $myconf->{iln} and length $myconf->{iln}) {
			 $myconf->{iln} =~ s/^\s+|\s+$//g; # Trim whitespaces
			 $myconf->{rcr} = join("|", $sudoc->getRcrFromIln($myconf->{iln}));
		}		
        $self->store_data($myconf);
        $template->param( 'config_success' => 'La configuration du plugin a été enregistrée avec succès !' );
    }
        my @rcr = split(/\|/, $self->retrieve_data('rcr'));
        $template->param(
            iln             => $self->retrieve_data('iln'),
            rcr             => \@rcr,
        );

		$self->output_html( $template->output() );
}


## If your plugin needs to add some CSS to the staff intranet, you'll want
## to return that CSS here. Don't forget to wrap your CSS in <style>
## tags. By not adding them automatically for you, you'll have a chance
## to include external CSS files as well!
 sub intranet_head {
     my ( $self ) = @_;
	 	
	 	return q|
	        <style>
	          .iln {
	             background: #b9d8d9;
	          }
	          #ppn.success {
	             color:#0C9618 !important;
	          }
	          #ppn.failed {
		         color: #900 !important;
		      }
	        </style>
		|;


 }

# If your plugin needs to add some javascript in the staff intranet, you'll want
# to return that javascript here. Don't forget to wrap your javascript in
# <script> tags. By not adding them automatically for you, you'll have a
# chance to include other javascript files if necessary.
sub intranet_js {
    my ( $self ) = @_;
    
    return q|
        <script>
	$(document).ready(function () {
		if (jQuery('body#catalog_detail').size() > 0) {
			checkSudoc();
		}
	});


function checkSudoc() {
	jQuery('#toolbar').after('<div id="notifications"></div>');
	if (jQuery("#ppn").size() > 0) {
		var PPN = jQuery('#ppn').text();
		locateInSudoc(PPN);
		isMerged(PPN);
	}
	else if (jQuery('.ISBN').size() > 0) {
		var isbns = getISBN();
		console.log(isbns);
		isbn2ppn(isbns);
	}	

}

//--------------------------
//   Sudoc controls
//--------------------------
function controlSudoc() {
	var message = "";
	if (jQuery('#infosSudoc').size() > 0 && jQuery('.iln').size() > 0 && jQuery('.nosudoc').size() > 0 && jQuery('#ppn.success').size() > 0) {
		message = "Notice sans PPN dans koha alors que la biblioth&egrave;que est toujours localis&eacute;e dans le sudoc";
	}
	else if (jQuery('#infosSudoc').size() > 0 && jQuery('.iln').size() > 0 && jQuery('#noitems').size() > 0 && jQuery('#typdoc.isSerial').size() == 0) {
		message = "Notice sans exemplaire mais toujours localis&eacute;e dans le sudoc";
	}
	else if (jQuery('#infosSudoc').size() > 0 && jQuery('.iln').size() > 0 && jQuery('#noitemsavailable').size() > 0 && jQuery('#typdoc.isSerial').size() == 0) {
		message = "Tous les exemplaires sont retir&eacute;s/perdus alors que la biblioth&egrave;que est toujours localis&eacute;e dans le sudoc";
	}
	else if (jQuery('#infosSudoc').size() > 0 && jQuery('.nosudoc').size() > 0 && jQuery('#nosudocloc').size() > 0) {
		message = "Notice catalogu&eacute;e localement alors qu'une notice PPN existe dans le sudoc";
	}
	else if (jQuery('#infosSudoc').size() > 0 && jQuery('.iln').size() == 0 && jQuery('#ppn').size() > 0) {
		message = "PPN pr&eacute;sent dans koha mais impossible de d&eacute;tecter un exemplaire de notre ILN dans le sudoc. Merci de v&eacute;rifier que nous sommes bien localis&eacute;s.<br />Si la notice vient d'&ecirc;tre catalogu&eacute;e, il peut y avoir un d&eacute;lai avant que le sudoc ne diffuse notre localisation.";
	}
	else if (jQuery('#infosSudoc').size() == 0 && jQuery('#ppn').size() > 0) {
		message = "Il semblerait que le PPN inscrit n'existe pas dans le sudoc.<br />Si la notice vient d'&ecirc;tre cr&eacute;&eacute;e dans le sudoc, il peut y avoir un d&eacute;lai avant qu'elle ne soit visible par Koha.";
	}

	if ((jQuery('.controlsudoc').length == 0) && message != "") {
		var toAlert = jQuery('<div class="alert controlsudoc"></div>').html("<strong>Anomalie :</strong> " + message);
		jQuery('#notifications').append(toAlert);
	}
}

function isMerged(PPN) {
	var url = "https://www.sudoc.fr/services/merged/" + PPN + "&format=text/json";
	$.ajax({
		url: url,
		dataType: 'json',
		jsonpCallback: 'mycallback',
		jsonp: false,
		success: function (data) {
			if (data.sudoc && data.sudoc.query.result.ppn.length > 0) {
				var PPNmerged = data.sudoc.query.result.ppn;
				if (PPN) {
					var url = jsHost + OPAC_SVC + 'json.getSru.php?index=dc.identifier&q=' + PPNmerged + '&callback=?';
					jQuery.getJSON(url)
						.done(function (data) {
							if (data && data.record) {
								jQuery.each(data.record, function (i, record) {
									if (record.biblionumber) {
										var toAlert = jQuery('<div class="alert controlmerged"></div>').html("<strong>Attention Fusion</strong> la notice du PPN " + PPN + " a &eacute;t&eacute; supprim&eacute;e et fusionn&eacute;e. Le PPN de la notice retenue est : <a href='https://www.sudoc.fr/" + PPNmerged + "' target='_blank' title='voir dans le sudoc' >" + PPNmerged + "</a> <a href='/cgi-bin/koha/catalogue/detail.pl?biblionumber=" + record.biblionumber + "' target='_blank'  title='voir dans Koha' >(voir dans Koha)</a>. ");
										jQuery('#notifications').append(toAlert);
									}
								});
							}
							else {
								var toAlert = jQuery('<div class="alert controlmerged"></div>').html("<strong>Attention Fusion</strong> la notice du PPN " + PPN + " a &eacute;t&eacute; supprim&eacute;e et fusionn&eacute;e. Le PPN de la notice retenue est : <a href='https://www.sudoc.fr/" + PPNmerged + "' target='_blank' title='voir dans le sudoc' >" + PPNmerged + "</a> (non pr&eacute;sent dans Koha). ");
								jQuery('#notifications').append(toAlert);
							}


						});
				}
			}
		}
	});
}


//--------------------------
//  Is ILN is located in Sudoc
//--------------------------
function sortResults(obj, prop, asc) {
	obj = obj.sort(function (a, b) {
		if (asc) return (a[prop] > b[prop]) ? 1 : ((a[prop] < b[prop]) ? -1 : 0);
		else return (b[prop] > a[prop]) ? 1 : ((b[prop] < a[prop]) ? -1 : 0);
	});
	return obj;
}

function prepareDeeplink(rcr, deeplink, ppn) {
	//console.log(deeplink);
	if (deeplink != null) {
		deeplink = deeplink.replace(/#Ppn#/g, ppn);
	}
	jQuery('#link_' + ppn + '_' + rcr + ' .multiwhere a.deeplink').attr('href', deeplink).attr('target', '_blank');
}

function isSudoc(rcr, PPN) {
	if (jQuery('.rcr' + rcr + '.iln').size() == 0) {
		jQuery('.rcr' + rcr).each(function () {
			jQuery(this).addClass('iln');
			jQuery(this).append(' <i class="fa fa-home"></i>');
			
		})
	}
		
	if (jQuery('#ppn.success').size() == 0) {
		if ((jQuery('#infosSudoc').size() > 0) && (jQuery('.iln').size() > 0)) {			
			jQuery('#ppn').addClass("success");
		}
		else {
			jQuery('.nosudoc').attr('id', "nosudocloc");
		}

	}
}

function iln2rcr(ILN, PPN) {
	var url = "https://www.idref.fr/services/iln2rcr/" + ILN + "&format=text/json";
	rcr = "| . $self->retrieve_data('rcr') . q|";
	var rcrArray = rcr.split("\|");
	console.log(rcrArray);
		jQuery.each(rcrArray, function (i, r) {
			isSudoc(r, PPN)
			console.log(r);
		});
		controlSudoc();

}

function isbn2ppn(arr) {
	jQuery.each(arr, function (i, ISBN) {
		var url = "https://www.sudoc.fr/services/isbn2ppn/" + ISBN + "&format=text/json";
		jQuery.getJSON(url)
			.done(function (data) {
				if (data && data.sudoc && data.sudoc.query && data.sudoc.query.result && data.sudoc.query.result.ppn) {
					locateInSudoc(data.sudoc.query.result.ppn);
				}
				else {
					jQuery.each(data.sudoc.query.result, function (i, result) {
						locateInSudoc(result.ppn)
					});
				}
			})
			.fail(function (jqxhr, textStatus, error) {
				var err = textStatus + ", " + error;
			});
	});
}

function locateInSudoc(PPN) {
	var url = "https://www.sudoc.fr/services/multiwhere/" + PPN + "&format=text/json";
	jQuery.getJSON(url)
		.done(function (data) {
			if (data && data.sudoc && data.sudoc.query && data.sudoc.query.result) {
				if (jQuery('#infosSudoc').size() == 0) {
					jQuery("#bibliodetails").tabs("add", "#infosSudoc", "Dans le SUDOC");
				}
				if (jQuery('#ppn_' + PPN).size() == 0) {
					var AppendPPN = jQuery('<div id=ppn_' + PPN + '></div>').html("<h5><a href='https://www.sudoc.fr/" + PPN + "' > " + PPN + "</a></h5>");
					jQuery('#infosSudoc').append(AppendPPN);
					if (data.sudoc.query.result.library.rcr) {
						var toAppend = jQuery('<div class="items" id="link_' + PPN + '_' + data.sudoc.query.result.library.rcr + '"></div>').html('<div class="multiwhere"><span class="whereis">Disponible &agrave; </span><a class="deeplink" href="http://www.sudoc.abes.fr/DB=2.1/SET=252/TTL=2/CMD?PRS=HOL/SHW?FRST=1&ACT=SRCHA&IKT=1016&SRT=RLV&TRM=ppn+' + PPN + '" target="_blank" title=""><span class="rcr' + data.sudoc.query.result.library.rcr + '">' + data.sudoc.query.result.library.shortname + '</span><br class="clear" /></a></div>');
						jQuery('#ppn_' + PPN).append(toAppend);
					}
					else {
						var libraries = data.sudoc.query.result.library;
						libraries = sortResults(libraries, 'shortname', true);
						jQuery.each(libraries, function (i, library) {
							var toAppend = jQuery('<div class="items" id="link_' + PPN + '_' + library.rcr + '"></div>').html('<div class="multiwhere"><span class="whereis">Disponible &agrave; </span><a class="deeplink" href="http://www.sudoc.abes.fr/DB=2.1/SET=252/TTL=2/CMD?PRS=HOL/SHW?FRST=1&ACT=SRCHA&IKT=1016&SRT=RLV&TRM=ppn+' + PPN + '" target="_blank" title=""><span class="rcr' + library.rcr + '">' + library.shortname + '</span><br class="clear" /></a></div>');
							jQuery('#ppn_' + PPN).append(toAppend);
						});
					}
				}
			}
			iln2rcr("| . $self->retrieve_data('iln') . q|", PPN);

		});
}



//--------------------------
//  FUNCT ISBN
//--------------------------
function getISBN() {
	var isbns = new Array();
	jQuery('.ISBN').each(function() {
		var	ISBN = jQuery(this).text().replace(/-/g,"");
		if (jQuery.inArray(ISBN, isbns) == -1){
			isbns.push(ISBN);
		}
		var ISBNbis = getOtherISBN(ISBN);
		if (jQuery.inArray(ISBNbis, isbns) == -1){
			isbns.push(ISBNbis);
		}
	});
	return isbns ;
}

function getOtherISBN($in){
	$in_light = $in.replace("-", "");
	$in_light = $in_light.replace(" ", "");

	if ($in_light.length == 10){
		return ISBN10toISBN13($in_light);
	}
	else if ($in_light.length == 13){
		return ISBN13toISBN10($in_light);
	}
	else{
		return null;
	}
}
/*
* Converts a isbn10 number into a isbn13.
* The isbn10 is a string of length 10 and must be a legal isbn10. No dashes.
*/
function ISBN10toISBN13(isbn10) {
    var sum = 38 + 3 * (parseInt(isbn10[0]) + parseInt(isbn10[2]) + parseInt(isbn10[4]) + parseInt(isbn10[6])
                + parseInt(isbn10[8])) + parseInt(isbn10[1]) + parseInt(isbn10[3]) + parseInt(isbn10[5]) + parseInt(isbn10[7]);
    var checkDig = (10 - (sum % 10)) % 10;
    return "978" + isbn10.substring(0, 9) + checkDig;
}

/*
* Converts a isbn13 into an isbn10.
* The isbn13 is a string of length 13 and must be a legal isbn13. No dashes.
*/
function ISBN13toISBN10(isbn13) {
    var start = isbn13.substring(3, 12);
    var sum = 0;
    var mul = 10;
    var i;
    for(i = 0; i < 9; i++) {
        sum = sum + (mul * parseInt(start[i]));
        mul -= 1;
    }
    var checkDig = 11 - (sum % 11);
    if (checkDig == 10) {
        checkDig = "X";
    } else if (checkDig == 11) {
        checkDig = "0";
    }
    return start + checkDig;
}

        </script>
    |;
}


## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
# sub install() {
#     my ( $self, $args ) = @_;

# }

## This is the 'upgrade' method. It will be triggered when a newer version of a
## plugin is installed over an existing older version of a plugin
sub upgrade {
    my ( $self, $args ) = @_;

    my $dt = dt_from_string();
    $self->store_data( { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') } );

    return 1;
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
    my ( $self, $args ) = @_;

}



## API methods
# If your plugin implements API routes, then the 'api_routes' method needs
# to be implemented, returning valid OpenAPI 2.0 paths serialized as a hashref.
# It is a good practice to actually write OpenAPI 2.0 path specs in JSON on the
# plugin and read it here. This allows to use the spec for mainline Koha later,
# thus making this a good prototyping tool.

# sub api_routes {
#     my ( $self, $args ) = @_;

#     my $spec_str = $self->mbf_read('openapi.json');
#     my $spec     = decode_json($spec_str);

#     return $spec;
# }

# sub api_namespace {
#     my ( $self ) = @_;
    
#     return 'sudoc';
# }

1;
