# JDialog - a translation of `tk_dialog' from Tcl/Tk to TkPerl (based on
# John Stoffel's idea).
#
# Modified 2/13/97 by Jim Turner of Computer Sciences Corporation to
# add underline character (alt-key) activation of buttons, fix bug in the
# bindings for <Return> key where default button always activated even if
# another button had the keyboard focus.  Now, the default button starts
# with the input focus!!!
#
# Jim Turner also added the "escape_button" option on 2/14/97 to allow
# programmer to specify a button to invoke if user presses the <Escape> key!
# Jim Turner also added the "images" option on 2/14/97 to allow programmer
# to specify gifs in leu of text for the buttons.
#
# Jim Turner also removed the "wraplength" option on 2/19/97 to allow
# longer label strings (>3") to not be broken.  User can specify -wraplength!
# Stephen O. Lidie, Lehigh University Computing Center.  94/12/27
# lusol@Lehigh.EDU
#
# 04/22/97 Jim Turner fixed bug where screen completely locks up if the calling
# script invokes a Motif app (ie. xv or another Perl/Tk app) shortly after    
# calling this dialog box.  Did not seem to adversely effect keyboard focus.
# fixed by commenting out 1 line of code (&$old_focus);
#
# This is an OO implementation of `tk_dialog'.  First, create all your Dialog
# objects during program initialization.  When it's time to use a dialog, 
# invoke the `show' method on a dialog object; the method then displays the 
# dialog, waits for a button to be invoked, and returns the text label of the 
# selected button.
#
# A Dialog object essentially consists of two subwidgets: a Label widget for
# the bitmap and a Label wigdet for the text of the dialog.  If required, you 
# can invoke the `configure' method to change any characteristic of these 
# subwidgets.
#
# Because a Dialog object is a Toplevel widget all the 'composite' base class
# methods are available to you.
#
# Advertised widgets:  bitmap, message.
#
# 1) Call the constructor to create the dialog object, which in turn returns 
#    a blessed reference to the new composite widget:
#
#    require Tk::JDialog;
#
#    $DialogRef = $mw->JDialog(
#        -title          => $title,
#        -text           => $text,
#        -bitmap         => $bitmap,
#        -default_button => $default_button,
#        -escape_button  => $escape_button,
#        -buttons        => [@button_labels],
#	 -images         => ['gif-file1','gif-file2'...]
#    );
#
#       mw             - a window reference, usually the result of a
#                        MainWindow->new call.
#       title          - Title to display in the dialog's decorative frame.
#                        NOTE: Jim Turner added optional tilde to "title"
#                        to specify a character to be the "underline" char.
#       text           - Message to display in the dialog widget.
#       bitmap         - Bitmap to display in the dialog.
#       default_button - Text label of the button that is to display the
#                        default ring (''signifies no default button).
#       escape_button  - Text label of the button that is to be invoked 
#                        when the user presses the <Esc> key.
#       button_labels  - A reference to a list of one or more strings to
#                        display in buttons across the bottom of the dialog.
#       images         - Specify the path and fid for an image or '' if a
#                        corresponding button is to use text.  NOTE: button
#                        will use text if the image file is not found and
#                        that the "-button_labels" option MUST ALWAYS be 
#                        specified anyway!
#       noballoons     - if true, do not display the "button_labels" value 
#                        in a balloon if images are used.
#
# 2) Invoke the `show' method on a dialog object:
#
#    $button_label = $DialogRef->Show;
#
#       This returns the text label of the selected button.
#
#    (Note:  you can request a global grab by passing the string "-global"
#    to the `show' method.)

package Tk::JDialog;
use Carp;
use strict qw(vars);
our $useBalloon;
use  Tk::Balloon; $useBalloon = 1;
require Tk::Toplevel;
@Tk::JDialog::ISA = qw(Tk::Toplevel);

Tk::Widget->Construct('JDialog');

sub Populate
{

    # Dialog object constructor.  Uses `new' method from base class
    # to create object container then creates the dialog toplevel.

    my($cw, $args) = @_;

    $cw->SUPER::Populate($args);

    my ($w_bitmap,$w_but,$pad1,$pad2,$underlinepos,$mychar,$blshow,$i);
    my ($btnopt,$undopt,$balloon);

    my $buttons = delete $args->{'-buttons'};
    my $images = delete $args->{'-images'};
    $buttons = ['OK'] unless (defined $buttons);
    my $default_button = delete $args->{-default_button};
    my $escape_button = delete $args->{-escape_button};
    my $noballoons = delete $args->{-noballoons};
    $useBalloon = 0  if ($noballoons);
    $default_button =  $buttons->[0] unless (defined $default_button);

    # Create the Toplevel window and divide it into top and bottom parts.

    $cw->{'selected_button'} = '';
    my (@pl) = (-side => 'top', -fill => 'both');
    ($pad1, $pad2) =
        ([-padx => '3m', -pady => '3m'], [-padx => '3m', -pady => '2m']);

    $cw->withdraw;
    $cw->iconname('JDialog');
    $cw->protocol('WM_DELETE_WINDOW' => sub {});
#?????????????????    $cw->transient($cw->toplevel)  unless ($^O =~ /Win/i);

    my $w_top = $cw->Frame(Name => 'top',-relief => 'raised', -borderwidth => 1);
    my $w_bot = $cw->Frame(Name => 'bot',-relief => 'raised', -borderwidth => 1);
    $w_top->pack(@pl);
    $w_bot->pack(@pl);

    # Fill the top part with the bitmap and message.

    @pl = (-side => 'left');

    $w_bitmap = $w_top->Label(Name => 'bitmap');
    $w_bitmap->pack(@pl, @$pad1);
    my $w_msg = $w_top->Label(
	#-wraplength => '3i',    --!!! Removed 2/19 by Jim Turner
	-justify    => 'left' );

    $w_msg->pack(-side => 'right', -expand => 1, -fill => 'both', @$pad1);

    # Create a row of buttons at the bottom of the dialog.

    my($w_default_button, $bl) = (undef, '');
    $cw->{'default_button'} = undef;
    $cw->{'escape_button'} = undef;
    $i = 0;
    foreach $bl (@$buttons) {

	$blshow = $bl;
	$underlinepos = ($blshow =~ s/^(.*)~/$1/) ? length($1): undef;
	if (defined($$images[$i]) && $$images[$i] gt ' ' && -e $$images[$i])
	{
		$cw->Photo($blshow, -file => $$images[$i]);
		$btnopt = '-image';
	}
	else
	{
		$btnopt = '-text';
	}
	if (defined($underlinepos))
	{
		$mychar = substr($blshow,$underlinepos,1);
		$w_but = $w_bot->Button(
		    $btnopt => $blshow,
		    -underline => $underlinepos,
		    -command => [
			sub {
			    $_[0]->{'selected_button'} = $_[1];
			}, $cw, $bl,
		    ]
		);
		$cw->bind("<Alt-\l$mychar>", [$w_but => "Invoke"]);
		$cw->bind("<Key-\l$mychar>", [$w_but => "Invoke"]);
	}
	else
	{
		$w_but = $w_bot->Button(
		    $btnopt => $blshow,
		    -command => [
			sub {
			    $_[0]->{'selected_button'} = $_[1];
			}, $cw, $bl,
		    ]
		);
	}
	if ($useBalloon && $btnopt eq '-image')
	{
		$balloon = $cw->Balloon();
		$balloon->attach($w_but, -state => 'balloon', -balloonmsg => $blshow);
	}
        if ($bl eq $default_button) {
            $w_default_button = $w_bot->Frame(
                -relief      => 'sunken',
                -borderwidth => 1
            );
            $w_but->raise($w_default_button);
            $w_default_button->pack(@pl, -expand => 1, @$pad2);
            $w_but->pack(-in => $w_default_button, -padx => '2m',
                         -pady => '2m');
    	    $cw->{'default_button'} = $w_but;
goto JWT_SKIP1;
            $cw->bind(
                '<Return>' => [
                    sub {
                        $_[1]->flash; 
                        $_[2]->{'selected_button'} = $_[3];
                    }, $w_but, $cw, $bl,
                ]
            );
JWT_SKIP1:
        } else {
            $w_but->pack(@pl, -expand => 1, @$pad2);
    	    $cw->{'default_button'} = $w_but  unless(defined($cw->{'default_button'}));
        }
	if ($bl eq $escape_button)
	{
            $cw->{'escape_button'} = $w_but;
            $cw->bind('<Escape>' => [$w_but => "Invoke"]);
	}
        ++$i;
    } # forend all buttons

    $cw->Advertise(message => $w_msg);
    $cw->Advertise(bitmap  => $w_bitmap );
    #!!!$cw->{'default_button'} = $w_default_button;

	if ($^O =~ /Win/i)
	{
		$cw->ConfigSpecs(
				-image      => ['bitmap',undef,undef,undef],
				-bitmap     => ['bitmap',undef,undef,undef],
				-fg         => ['ADVERTISED','foreground','Foreground','black'],
				-foreground => ['ADVERTISED','foreground','Foreground','black'],
				-bg         => ['DESCENDANTS','background','Background',undef],
				-background => ['DESCENDANTS','background','Background',undef],
		DEFAULT     => ['message',undef,undef,undef]
		);
	}
	else
	{
		$cw->ConfigSpecs(
				-image      => ['bitmap',undef,undef,undef],
				-bitmap     => ['bitmap',undef,undef,undef],
				-fg         => ['ADVERTISED','foreground','Foreground','black'],
				-foreground => ['ADVERTISED','foreground','Foreground','black'],
				-bg         => ['DESCENDANTS','background','Background',undef],
				-background => ['DESCENDANTS','background','Background',undef],
		# JWT for TNT!  -font       => ['message','font','Font','-*-Times-Medium-R-Normal-*-180-*-*-*-*-*-*'],
				-font       => ['message','font','Font','-adobe-helvetica-bold-r-normal--17-120-100-100-p-92-iso8859-1'],
		DEFAULT     => ['message',undef,undef,undef]
		);
	}
} # end Dialog constructor

sub Show {

    # Dialog object public method - display the dialog.

    my ($cw, $grab_type) = @_;

    croak "Dialog:  `show' method requires at least 1 argument"
        if scalar @_ < 1 ;

    #!!! my $old_focus = $cw->focusSave;  # don't need (Jim Turner) after fixing BUG!
    my $old_grab  = $cw->grabSave;

    # Update all geometry information, center the dialog in the display
    # and deiconify it

    $cw->Popup(); 

    # set a grab and claim the focus.

		 unless ($ENV{DESKTOP_SESSION} =~ /kde/)
		 {
	    if (defined $grab_type && length $grab_type) {
	        $cw->grab($grab_type)  if ($grab_type !~ /no/i);  #JWT: ADDED 20010517 TO ALLOW NON-GRABBING!
	    } else {
	        $cw->grab;
	    }
		 }
############## $cw->waitVisibility;  #SEEMS TO HANG ON NEWER TK'S.
	$cw->update;
    if (defined $cw->{'default_button'}) 
     {
      $cw->{'default_button'}->focus;
     } 
    else
     {
      $cw->focus;
     }

    # Wait for the user to respond, restore the focus and grab, withdraw
    # the dialog and return the label of the selected button.

    $cw->waitVariable(\$cw->{'selected_button'});
    $cw->grabRelease;
    $cw->withdraw;
    #!!! &$old_focus;   #FIXED BUG CAUSING COMPLETE SCREEN LOCKUP IF ANOTHER
			#MOTIF APP (WINDOW) IS POPPED UP SHORTLY AFTERWARDS!
    &$old_grab;
    return $cw->{'selected_button'};

} # end Dialog show method

1;
