#!/usr/bin/perl -s

#NOTE: Windows compile:  pp -g -M Tk::Text -M Crypt::CBC -M Crypt::DES -M Tk::SMListbox -o ptkftp.exe ptkftp.pl
#NOTE: Alternate Windows compile:  perl2exe -gui -perloptions="-s" ptkftp.pl

BEGIN
{
	if ($0 =~ /exe$/io)    #THIS SECTION NEEDED BY PAR COMPILER!
	{
		while (@INC)
		{
			$_ = shift(@INC);
			push (@myNewINC, $_)  if (/(?:cache|CODE)/o);
		}
		@INC = @myNewINC;		
		use Tk::Listbox;
		use Tk::MListbox;
		use Tk::SMListbox;
		require Crypt::CBC;		
		$haveCrypt = 1;
	}
	$haveFTP = 0;
	$haveSFTP = 0; 
	$haveSSH2 = 0;
	$bummer = $^O =~ /Win/io ? 1 : 0;
	eval 'use constant; 1';   #DUMMY MODULE REQUIRED BY PERL2EXE!
	eval 'use Net::SSH::W32Perl::SSH2; 1';    #REQUIRED BY PERL2EXE!
	eval '
		use Net::SSH::Perl::Constants;       #REQUIRED BY PERL2EXE!
		use Net::SSH::Perl::Util::SSH2MP;    #REQUIRED BY PERL2EXE!
		use Net::SSH::Perl::Util::Hosts;     #REQUIRED BY PERL2EXE!
		use Net::SSH::Perl::Util::Term;      #REQUIRED BY PERL2EXE!
		use Net::SSH::Perl::Cipher::DES3;    #REQUIRED BY PERL2EXE!
		use Net::SFTP;
		use Crypt::Random;
		use Crypt::Random::Provider::rand;   #REQUIRED BY PERL2EXE!
		use Net::SSH::Perl::Key::DSA;        #REQUIRED BY PERL2EXE!
		use Net::SSH::Perl::Auth::PublicKey; #REQUIRED BY PERL2EXE!
		use Net::SSH::Perl::Auth::Password;  #REQUIRED BY PERL2EXE!
		use Net::SFTP::Util qw( fx2txt );
		$haveSFTP = 1;
		1
	';
	eval 'use Net::SSH2; $haveSSH2 = 1; 1';
	$SIG{ALRM} = sub {
		alarm(0)  unless ($bummer);
		if ($keepopen)
		{
#			if ($sftp)
#			{
#				eval { $sftp->ls('.'); };
#				#IF THIS DOESN'T DO THE TRICK TRY UNCOMMENTING THE FOLLOWING:
#				#eval { $sftp->put("$ENV{HOME}/.ptkftp.tst", ".ptkftp.$$.tmp"); };
#				#eval { $sftp->do_remove(".ptkftp.$$.tmp"); };
#			}
#			elsif ($ftp)
			if ($ftp)
			{
#				eval { $ftp->put("$ENV{HOME}/.ptkftp.tst", ".ptkftp.$$.tmp"); };
#				eval { $ftp->delete(".ptkftp.$$.tmp"); };
				eval { $ftp->ls('.') };
			}
print "-PING SERVER!\n";
			alarm(59 + int(rand(60)));  #RANDOMIZE THIS TO AVOID WRATH OF SOME ISP's!
		}
	};
};

use Net::xFTP;

#eval 'use Net::FTP; $haveFTP = 1; 1';
$haveFTP = Net::xFTP->haveFTP;
$haveSFTP = Net::xFTP->haveSFTP;
$haveSSH2 = Net::xFTP->haveSSH2;

use Cwd;
use File::Copy;
use Tk;
use Tk ':eventtypes';
use Tk::Menubutton;     #REQUIRED BY PERL2EXE!
use Tk::Checkbutton;    #REQUIRED BY PERL2EXE!
use Tk::Radiobutton;    #REQUIRED BY PERL2EXE!
use Tk::JBrowseEntry;
use Tk::JDialog;
#use Tk::MListbox;
BEGIN {
	$haveSMListbox = 0;
	eval 'use Tk::SMListbox; $haveSMListbox = 1; 1';
	unless ($haveSMListbox) {
		use Tk::MListbox;
	}
}

$haveROText = 'Text';
eval 'use Tk::ROText; $haveROText = "ROText"; 1';
eval 'require "BindMouseWheel.pl"; $WheelMouse = 1; 1';
my $Win32 = 0;
eval 'use Win32; $Win32 = 1; 1'  if ($bummer);

if ($bummer)
{
	$ENV{HOME} ||= $ENV{USERPROFILE}  if (defined $ENV{USERPROFILE});
	$ENV{HOME} ||= $ENV{ALLUSERSPROFILE}  if (defined $ENV{ALLUSERSPROFILE});
	$ENV{HOME} =~ s#\\#\/#gso;
}
$pgmhome = $0;
$pgmhome =~ s#[^/]*$##;  #SET NAME TO SQL.PL FOR ORAPERL!
$pgmhome ||= './';
$pgmhome .= '/'  unless ($pgmhome =~ m#/$#);
$pgmhome = 'c:/perl/bin/'  if ($bummer && $pgmhome =~ /^\.[\/\\]$/o);

$homedir ||= $ENV{HOME} || '.';
$homedir .= '/'  unless ($homedir =~ m#\/$#o);
$hometmp = (-w "${homedir}tmp") ? "${homedir}tmp" : '/tmp';

#require 'JCutCopyPaste.pl';
require "setPalette.pl";

$VERSION = '1.00';
$viewer = $bummer ? 'c:\Program Files\Windows NT\Accessories\wordpad' : 'xterm -title Editor -e vi -R';
$editor = $bummer ? 'c:\Program Files\Windows NT\Accessories\wordpad' : 'xterm -title Viewer -e vi';
#$diffcmd = 'xterm -e diff';
$diffcmd = 'diff %1 %2 >$HOME/.ptkftp.diff; xterm -title diff -e vi -R $HOME/.ptkftp.diff';

$localhost = `hostname`;
chomp($localhost);
$localhost ||= 'Local';
#$dirsep = ($bummer) ? '\\' : '/';
$dirsep = '/';  #ALWAYS, SEEMS TO WORK!
$useftp = '';

$MainWin = MainWindow->new;
$headTitle = "(S)FTP Client by Jim Turner, v$VERSION";
$MainWin->title("$localhost: $headTitle");
unless ($c)
{
	eval { $MainWin->optionReadfile("$ENV{HOME}/.Xdefaults") or $MainWin->optionReadfile('/etc/Xdefaults'); };
	$c = $MainWin->optionGet('tkPalette','*');
}
$MainWin->setPalette($c)  if ($c);

$loginWin = $MainWin->Toplevel;
$loginWin->withdraw;
$loginWin->title('Remote Host Login:');
$remoteuserSel = $loginWin->JBrowseEntry(
		-label => 'User-id',
		-variable => \$remoteuser,
		-labelPack => [-side => 'top'],
		-tabcomplete => 1,
		-browsecmd => sub {
				$remotepswd = $prevpswds{$remote}->{$remoteuser} || '';
				$rememberpswd = $remotepswd ? 1 : 0;
		},
)->pack(-side => 'top', -fill => 'x', -padx => 10, -pady => 10);
$remotepswdEntry = $loginWin->LabEntry(
		-label => 'Password',
		-show => '*',
		-textvariable => \$remotepswd,
)->pack(-side => 'top', -fill => 'x', -padx => 10, -pady => 10);
$remotepswdEntry->bind('<Return>', sub {$loginOkBtn->Invoke;});
$remotepswdEntry->bind('<Escape>', [$loginCanBtn => "Invoke"]);
$loginBtnFrame = $loginWin->Frame->pack(-side => 'top', -fill => 'x', -padx => 10, -pady => 10);
$loginOkBtn = $loginBtnFrame->Button(
		-text => 'Ok',
		-underline => 0,
		-command => [\&loginOkFn]
)->pack(-side => 'left', -anchor => 'w', -padx => 0, -pady => 10);
$loginCanBtn = $loginBtnFrame->Button(
		-text => 'Cancel',
		-underline => 0,
		-command => [\&loginCanFn]
)->pack(-side => 'right', -anchor => 'e', -padx => 0, -pady => 10);
$rpswdCkbtn = $loginWin->Checkbutton(
	-text   => 'Remember password',
	-variable=> \$rememberpswd
)->pack(-side => 'top');

$renameWin = $MainWin->Toplevel;
$renameWin->withdraw;
$renameWin->title('Rename file:');
$oldnameEntry = $renameWin->LabEntry(
		-label => 'Old name:',
		-textvariable => \$oldname,
)->pack(-side => 'top', -fill => 'x', -padx => 10, -pady => 10);
$newnameEntry = $renameWin->LabEntry(
		-label => 'new name:',
		-textvariable => \$newname,
)->pack(-side => 'top', -fill => 'x', -padx => 10, -pady => 10);
$newnameEntry->bind('<Return>', sub {$renameOkBtn->Invoke;});
$renameWin->bind('<Escape>', [$renameCanBtn => "Invoke"]);
$renameBtnFrame = $renameWin->Frame->pack(-fill => 'x', -padx => 10, -pady => 10);
$renameOkBtn = $renameBtnFrame->Button(
		-text => 'Ok',
		-underline => 0,
		-command => [\&renameOkFn]
)->pack(-side => 'left', -anchor => 'w', -padx => 0, -pady => 10);
$renameCanBtn = $renameBtnFrame->Button(
		-text => 'Cancel',
		-underline => 0,
		-command => [\&renameCanFn]
)->pack(-side => 'right', -anchor => 'e', -padx => 0, -pady => 10);

$chmodWin = $MainWin->Toplevel;
$chmodWin->withdraw;
$chmodWin->title('Permissions');
$chmodEntry = $chmodWin->LabEntry(
		-label => 'chmod: (ie. 744): ',
		-width => 5,
		-textvariable => \$chmodValue,
		-labelPack => [qw/-side left/],
)->pack(-side => 'top', -fill => 'x', -padx => 30, -pady => 10);
$chmodBtnFrame = $chmodWin->Frame->pack(-fill => 'x', -padx => 30, -pady => 10);
$chmodOkBtn = $chmodBtnFrame->Button(
		-text => 'Ok',
		-underline => 0,
		-command => [\&chmodOkFn]
)->pack(-side => 'left', -anchor => 'w', -padx => 0, -pady => 10);
$chmodCanBtn = $chmodBtnFrame->Button(
		-text => 'Cancel',
		-underline => 0,
		-command => [\&chmodCanFn]
)->pack(-side => 'right', -anchor => 'e', -padx => 0, -pady => 10);
$chmodEntry->bind('<Return>', sub {$chmodOkBtn->Invoke;});
$chmodWin->bind('<Escape>', [$chmodCanBtn => "Invoke"]);

my $w_menu = $MainWin->Frame(-relief => 'raised', -borderwidth => 2);
$w_menu->pack(-fill => 'x');

my $fileMenubtn = $w_menu->Menubutton(
		-text => 'File', 
		-underline => 0, 
)->pack(-side=>'left');
$fileMenubtn->command(-label => 'diff',    -underline =>1, -command => \&diffFn);
$fileMenubtn->separator;
$fileMenubtn->command(-label => 'eXit',    -underline =>1, -command => \&exitFn);

my $localMenubtn = $w_menu->Menubutton(
		-text => 'Local', 
		-underline => 0, 
)->pack(-side=>'left');
$localMenubtn->command(-label => 'Delete local', -underline => 0, -command => [\&ldeleteFn]);
$localMenubtn->command(-label => 'Rename local', -underline => 0, -command => [\&lrenameFn]);
$localMenubtn->separator;
$localMenubtn->command(-label => 'Edit local', -underline => 0, -command => [\&leditFn]);
$localMenubtn->command(-label => 'View local', -underline => 0, -command => [\&lviewFn]);
$localMenubtn->command(-label => 'Permissions', -underline => 0, -command => [\&lchmodFn]);
$localMenubtn->separator;
$localMenubtn->command(-label => 'Create Subdir', -underline => 0, -command => [\&lmkdirFn]);
$localMenubtn->command(-label => 'Remove Subdir', -command => [\&lrmdirFn]);
$localMenubtn->command(-label => 'Show Size', -underline => 0, -command => [\&lshowsizeFn]);

my $remoteMenubtn = $w_menu->Menubutton(
		-text => 'remote', 
		-underline => 0, 
)->pack(-side=>'left');
$remoteMenubtn->command(-label => 'Delete remote', -underline => 0, -command => [\&rdeleteFn]);
$remoteMenubtn->command(-label => 'Rename remote', -underline => 0, -command => [\&rrenameFn]);
$remoteMenubtn->separator;
$remoteMenubtn->command(-label => 'Edit remote', -underline => 0, -command => [\&reditFn]);
$remoteMenubtn->command(-label => 'View remote', -underline => 0, -command => [\&rviewFn]);
$remoteMenubtn->command(-label => 'Permissions', -underline => 0, -command => [\&rchmodFn]);
$remoteMenubtn->separator;
$remoteMenubtn->command(-label => 'Create Subdir', -underline => 0, -command => [\&rmkdirFn]);
$remoteMenubtn->command(-label => 'Remove Subdir', -command => [\&rrmdirFn]);
$remoteMenubtn->command(-label => 'Show Size', -underline => 0, -command => [\&rshowsizeFn]);

%themeHash = ();
if (open (T, ".myethemes") || open (T, "${homedir}.myethemes")
		|| open (T, "${pgmhome}myethemes"))
{
	$themeMenuBtn = $w_menu->Menubutton(
			-text => 'themes', -underline => 0);
	$themeMenuBtn->pack(-side=>'left');
	my ($themename, $themecode);
	while (<T>)
	{
		chomp;
		($themename, $themecode) = split(/\:/o);
		$themeHash{$themename} = $themecode;
		eval "\$themeMenuBtn->command(-label => '$themename', -command => sub {&setTheme($themename);});";
	}
	close T;
}

my $helpMenubtn = $w_menu->Menubutton(
		-text => 'help',
		-underline => 0
)->pack(-side=>'right');
$helpMenubtn->command(-label => 'About', -underline =>0, -command => \&About);

$midFrame = $MainWin->Frame->pack(
		-side => 'top', 
		-fill => 'both', 
		-expand => 1,
	);
	$localFrame = $midFrame->Frame->pack(
			-side => 'left', 
			-fill => 'both', 
			-expand => 1,
			-padx => 10, -pady => 10
	);
		$localLabel = $localFrame->Entry(
				#-relief => 'sunken',
				-textvariable => \$localhost,
				-width => $w||44,
				-state => 'disabled',
		)->pack(-side => 'top', -fill => 'x', -pady => 15);
		$ldirSel = $localFrame->JBrowseEntry(
				-variable => \$ldir,
				-noselecttext => 1,
				-width => $w||44,
		-tabcomplete => 1,
				#-maxwidth => $w||0,
				#-noselecttext => 1,
				-browsecmd => sub {&lrefreshFn($ldir); },
		)->pack(-side => 'top', -fill => 'x');
		#$ldirSel->configure(-width => $w)  if ($w);
		#$ldirSel->configure(-maxwidth => $w)  if ($w);
		$ldirSel->bind('<Return>', sub {&lrefreshFn($ldir); });
		$lrefreshFrame = $localFrame->Frame->pack(-side => 'top', -fill => 'x');
#			if ($bummer)
#			{
			$windrive = '';
			if ($Win32 && $bummer)
			{
				$_ = Win32::GetNextAvailDrive();
				s/\W//g;
				my @driveletters = ('');
				for my $i ('A'..'Z')
				{
					last  if ($i eq $_);
					push (@driveletters, "$i:");
				}
				#$windrive ||= 'C:';
				$windriveSell = $lrefreshFrame->JBrowseEntry(
						-variable => \$windrive,
						-choices => \@driveletters,
						-noselecttext => 1,
						-browsecmd => sub {
#							if ($windrive)   #REMOVED 20040101
#							{
#								$ldir = '/';
#							}
#							else
#							{
#								$ldir = $ENV{PWD};
#							} 
							&lrefreshFn($windrive);
						},
				)->pack(-side => 'left');
			}
			$lrefreshBtn = $lrefreshFrame->Button(
					-text => 'Refresh',
					#-underline => 2,
					-command => [\&lrefreshFn]
			)->pack(-side => 'left', -fill => 'x', -expand => 1);
		$lfileFrame = $localFrame->Frame(-border => 4, -relief => 'groove')
		->pack(-side => 'top', -fill => 'both', -expand => 1);
		$lfileList = $lfileFrame->Scrolled(
				($haveSMListbox ? 'SMListbox' : 'MListbox'),
				-scrollbars => 'se', 
				#-width	 => 16,
				##-width => $w||0,
				-width => $w||44,
				-height => $listheight || 12,
				-relief => 'sunken',
				-sortable => 1,
				-selectmode => 'extended',
				-takefocus => 1,
				-columns => [
					[-text => 'D', -width => 3, -comparecommand => sub { $_[1] cmp $_[0]}],
					[-text => 'Name', -width => 20,],
					[-text => 'Perm.', -width => 10,],
					[-text => 'Owner:Group', -width => 13,],
					[-text => 'Size', -width => 6, -comparecommand => sub { $_[1] <=> $_[0]}],
					[-text => 'Date/Time', -width => 15,],
				]
		)->pack(-side => 'top', -fill => 'both', -expand => 1);
		#$lfileList->bind('<Double-ButtonRelease>' => [\&lfileClickFn]);
		$lfileList->bindRows('<ButtonRelease-1>' => [\&lfileClickFn]);
		$lfileList->bindRows('<Return>' => [\&lfileClickFn]);
		$lfileList->Subwidget('xscrollbar')->configure(-takefocus => 0);
		$lfileList->Subwidget('yscrollbar')->configure(-takefocus => 0);
		&BindMouseWheel($lfileList)  if ($WheelMouse);
	$midbtnFrame = $midFrame->Frame->pack(
			-side => 'left', 
			-padx => 10, -pady => 10
	);
		$connectBtn = $midbtnFrame->Button(
				-text => 'Connect',
				-underline => 0,
				-command => [\&connectFn]
		)->pack(-side => 'top', -padx => 5, -pady => 10);
		$connectBtn->configure(-state => 'disabled')  
				unless($haveFTP || $haveSFTP || $haveSSH2);
		my @protocolChoices = ();
		push (@protocolChoices, 'FTP')   if ($haveFTP);
		push (@protocolChoices, 'SSH2')  if ($haveSSH2);
		push (@protocolChoices, 'SFTP')  if ($haveSFTP);
		$usesftp ||= 'FTP'  if ($haveFTP);
		$usesftp ||= 'SSH2'  if ($haveSSH2);
		$usesftp ||= 'SFTP'  if ($haveSFTP);
		$sftpCkbtn = $midbtnFrame->JBrowseEntry(
			-label => 'Protocol:',
			-width => 5,
			-variable => \$usesftp,
			-choices => \@protocolChoices,
			-labelPack => [-side => 'top'],
			-tabcomplete => 1,
			-noselecttext => 1,
		)->pack(-side => 'top');
#		$MainWin->bind('<Alt-s>', sub {$usesftp = !$usesftp;});
		if ($bummer)   #KEEP-OPEN NOT SUPPORTED BY WINDUHS, SINCE "alarm()" NOT SUPPORTED!
		{
			$keepopen = 0;
		}
		else
		{
			$keepopenCkbtn = $midbtnFrame->Checkbutton(
				-text   => 'Keep open',
				-variable=> \$keepopen
			)->pack(-side => 'top');
			$MainWin->bind('<Alt-k>', sub {
					$keepopen = !$keepopen;
					alarm(119)  if ($keepopen);
			});
		}
#		$sftpCkbtn->configure(-state => 'disabled')  unless ($haveSFTP);
		$xferFrame = $midbtnFrame->Frame(
				-relief => 'groove',
				-borderwidth => 2,
		)->pack(-side => 'top', -padx => 5, -pady => 10);
			$xfermode ||= 'binary';
			$xfermodeBtnAscii = $xferFrame->Radiobutton(
					-text   => 'Ascii   ',
					-highlightthickness => 1,
					-variable=> \$xfermode,
					-underline => 0,
					-value  => 'ascii')->pack(-side => 'top');
		$MainWin->bind('<Alt-a>', sub {$xfermode = 'ascii';});
			$xfermodeBtnBinary = $xferFrame->Radiobutton(
					-text   => 'Binary',
					-highlightthickness => 1,
					-variable=> \$xfermode,
					-underline => 0,
					-value  => 'binary')->pack(-side => 'top');
		$MainWin->bind('<Alt-b>', sub {$xfermode = 'binary';});
		$downloadBtn = $midbtnFrame->Button(
				-text => '<<<<<',
				#-underline => 0,
				-command => [\&downloadFn]
		)->pack(-side => 'top', -padx => 5, -pady => 10);
		$uploadBtn = $midbtnFrame->Button(
				-text => '>>>>>',
				#-underline => 0,
				-command => [\&uploadFn]
		)->pack(-side => 'top', -padx => 5, -pady => 10);
		$showallCkbtn = $midbtnFrame->Checkbutton(
			-text   => 'Show All',
			-variable=> \$showall
		)->pack(-side => 'top');

	$remoteFrame = $midFrame->Frame->pack(
			-side => 'left', 
			-fill => 'both', 
			-expand => 1,
			-padx => 10, -pady => 10
	);
		$remoteSel = $remoteFrame->JBrowseEntry(
				-variable => \$remote,
				#-maxwidth => $w||0,
				-maxwidth => $w||44,
				-tabcomplete => 1,
				-noselecttext => 1,
				-choices => [],
				-browsecmd => sub {
						$usesftp = $prevsftp{$remote};
						$keepopen = $prevkeep{$remote};
				},
		)->pack(-side => 'top', -fill => 'x', -pady => 15);
		#$remoteSel->configure(-maxwidth => $w)  if ($w);
		$rdirSel = $remoteFrame->JBrowseEntry(
				-variable => \$rdir,
				-width => $w||44,
				-tabcomplete => 1,
				#-maxwidth => $w||40,
				-noselecttext => 1,
				-browsecmd => sub { &rrefreshFn($rdir); },
		)->pack(-side => 'top', -fill => 'x');
		$rdirSel->bind('<Return>', sub {&rrefreshFn($rdir); });
		#$rdirSel->configure(-maxwidth => $w)  if ($w);
		$rrefreshFrame = $remoteFrame->Frame->pack(-side => 'top', -fill => 'x');
			$rrefreshBtn = $rrefreshFrame->Button(
					-text => 'Refresh',
					#-underline => 2,
					-command => [\&rrefreshFn]
			)->pack(-side => 'left', -fill => 'x', -expand => 1);
		$rfileFrame = $remoteFrame->Frame(-border => 4, -relief => 'groove')
		->pack(-side => 'top', -fill => 'both', -expand => 1);
		$rfileList = $rfileFrame->Scrolled(
				($haveSMListbox ? 'SMListbox' : 'MListbox'),
				-scrollbars => 'se', 
				#-width	 => 16,
				##-width => $w||0,
				-width => $w||44,
				-height => $listheight || 12,
				-relief => 'sunken',
				-selectmode => 'extended',
				-takefocus => 1,
				-columns => [
					[-text => 'D', -width => 3, -comparecommand => sub { $_[1] cmp $_[0]}],
					[-text => 'Name', -width => 20,],
					[-text => 'Perm.', -width => 10,],
					[-text => 'Owner:Group', -width => 13,],
					[-text => 'Size', -width => 6, -comparecommand => sub { $_[1] <=> $_[0]}],
					[-text => 'Date/Time', -width => 15,],
				]
		)->pack(-side => 'top', -fill => 'both', -expand => 1);
		#$rfileList->bind('<Double-ButtonRelease>' => [\&rfileClickFn]);
		$rfileList->bindRows('<ButtonRelease-1>' => [\&rfileClickFn]);
		$rfileList->bindRows('<Return>' => [\&rfileClickFn]);
		$rfileList->Subwidget('xscrollbar')->configure(-takefocus => 0);
		$rfileList->Subwidget('yscrollbar')->configure(-takefocus => 0);
		&BindMouseWheel($rfileList)  if ($WheelMouse);
#$statusText = $MainWin->ROText(
$statusText = $MainWin->Scrolled($haveROText,
		-scrollbars => 'e', 
		-width => 60, 
		-height => $h||6,
		-takefocus => 0,
)->pack(-side => 'top', -fill => 'both', -expand => 1);
		&BindMouseWheel($statusText)  if ($WheelMouse);

my ($OK, $Cancel) = ('~OK', '~Cancel');
$DIALOG = $MainWin->JDialog(
		-title          => 'ERROR!',
		-text           => '',
		-bitmap         => 'info',
		-default_button => $Cancel,
		-escape_button  => $Cancel,
		-buttons        => [$OK],
);

$DIALOG2 = $MainWin->JDialog(
		-title          => 'Are you Sure?',
		-text           => '',
		-bitmap         => 'info',
		-default_button => $Cancel,
		-escape_button  => $Cancel,
		-buttons        => [$OK, $Cancel],
);

&initFn;
$remoteSel->focus();

MainLoop;

sub initFn
{
	$remotename = $remote = $localhost;
	if (-r "$ENV{HOME}/.cdout" && open(F,"<$ENV{HOME}/.cdout"))
	{
		$ldir = <F>;
		chomp($ldir);
		close F;
	}
	$ldir ||= &cwd();
	my ($rhost, $unames, $paths, $lastdir, $lastuser, $lastsftp);
	$maxdirs = $h || 20;
	$haveCrypt = 0;
	$CBC = undef;
	eval { require Crypt::CBC; $haveCrypt = 1; };
	if ($crypt =~ /[a-zA-Z]/o)
	{
		die "-Could not require \"Crypt::CBC\" module, required by \"-crypt\" option!" 
				unless ($haveCrypt);
		$CBC = Crypt::CBC->new('key8ptk4', $crypt);
		die "-Could not create crypt object using crypt method \"$crypt\"!" 
				unless ($CBC);
		$haveCrypt = $crypt;
	}
	if (open(F, "<$ENV{HOME}/.ptkftp.prev"))
	{
		$_ = <F>;
		chomp;
		$maxdirs ||= $_  if (/^\d+$/o);
		$_ = <F>;
		chomp;
		$cryptmodule = $_;
		$_ = <F>;
		chomp;
		($editor, $viewer, $diffcmd) = split(/\|/o);
		unless ($crypt)
		{
			eval { $CBC = Crypt::CBC->new('key8ptk4', '$cryptmodule'); $haveCrypt = $cryptmodule; }  if ($haveCrypt && $cryptmodule =~ /[a-zA-Z]/);
			eval { $CBC = Crypt::CBC->new('key8ptk4', 'DES'); $haveCrypt = 'DES'; }  if ($haveCrypt && !$CBC);
			eval { $CBC = Crypt::CBC->new('key8ptk4', 'Blowfish_PP'); $haveCrypt = 'Blowfish_PP'; }  if ($haveCrypt && !$CBC);
		}
		$haveCrypt = ''  unless ($haveCrypt =~ /[a-zA-Z]/o);

		open(G, "<$ENV{HOME}/.ptkftp.users")  if ($CBC);
		my (@l, @l2);
		while (<F>)
		{
			chomp;
			($rhost, $unames, $paths, $lastdir, $lastuser, $lastsftp, $lastkeep) = split(/\|/o);
			if ($CBC)
			{
				$_ = <G>;
				chomp;
				($t, $pswds) = split(/\|/o);
				@l = split(/\<BR\>/, $pswds);
			}
			@l2 = split(/\:/o, $lastdir);
			$prevusers{$rhost} = [split(/\,/o, $unames)];
			$prevpaths{$rhost} = [split(/\,/o, $paths)];
			$lastuser{$rhost} = $lastuser;
			$prevsftp{$rhost} = $lastsftp || 'FTP';
		$prevsftp{$rhost} = ($haveSSH2 ? 'SSH2' : 'SFTP')  if ($prevsftp{$rhost} =~ /[1-9]/o);  #FIX LEGACY VALUES!
			$prevkeep{$rhost} = $lastkeep || '0';
			for (my $i=0;$i<=$#{$prevusers{$rhost}};$i++)
			{
				$l[$i] =~ s/\<NULL\>/\0/go;
				$l[$i] =~ s/\<LF\>/\n/go;
				eval { $prevpswds{$rhost}->{$prevusers{$rhost}->[$i]} = 
						($CBC && $l[$i]) ? $CBC->decrypt($l[$i]) : ''; };
				$prevpswds{$rhost}->{$prevusers{$rhost}->[$i]} =~ s/ +$//;
#print "-???- prevpswd(".$prevusers{$rhost}->[$i].")=".$prevpswds{$rhost}->{$prevusers{$rhost}->[$i]}."=\n";
				$lastpath{$rhost}->{$prevusers{$rhost}->[$i]} = $l2[$i];
			}
			unless ($lastpath{$rhost}->{''})
			{
				$lastpath{$rhost}->{''} = $l2[0]  if ($l2[0]);
			}
			push (@prevhosts, $rhost);
		}
		close G  if ($CBC);
		close F;
	}
	else
	{
		eval { $CBC = Crypt::CBC->new('key8ptk4', '$crypt'); $haveCrypt = $crypt; }  if ($haveCrypt && $cryptmodule =~ /[a-zA-Z]/);
		eval { $CBC = Crypt::CBC->new('key8ptk4', 'DES'); $haveCrypt = 'DES'; }  if ($haveCrypt && !$CBC);
		eval { $CBC = Crypt::CBC->new('key8ptk4', 'Blowfish_PP'); $haveCrypt = 'Blowfish_PP'; }  if ($haveCrypt && !$CBC);
		$haveCrypt = ''  unless ($haveCrypt =~ /[a-zA-Z]/o);
	}
	if ($CBC)
	{
		$loginWin->bind('<Alt-r>', sub {$rememberpswd = !$rememberpswd;});
	}
	else
	{
		$rpswdCkbtn->packForget()  unless ($CBC);
	}
	unless (-r "$ENV{HOME}/.ptkftp.tst")  #THIS FILE UPLOADED PERIODICALLY IF 
	{                                     #KEEPOPEN ON TO KEEP SERVERS FROM 
		if (open (F,">$ENV{HOME}/.ptkftp.tst"))  #TIMING OUT DUE TO INACTIVITY!
		{
			print F <<END_TEST;
Test file for use in testing ftp/sftp transfers.  
May be deleted!
END_TEST
			close F;
		}
	}
	
	@prevhosts = ($localhost)  unless ($#prevhosts >= 0);
	$remoteSel->choices(\@prevhosts);
	my $i = 0;
	while (1)
	{
		last  if ($i > $#{$prevpaths{$localhost}});
		if (-d ${$prevpaths{$localhost}}[$i])
		{
			++$i;
		}
		else
		{
			splice(@{$prevpaths{$localhost}}, $i, 1);
		}
	}
	if ($maxdirs > 0)
	{
		while ($#{$prevpaths{$localhost}} >= $maxdirs)
		{
			pop(@{$prevpaths{$localhost}});
		}
	}
	$ldirSel->choices($prevpaths{$localhost});
	$rdirSel->choices($prevpaths{$localhost});
	$rdir = (-d $lastpath{$localhost}->{''}) ? $lastpath{$localhost}->{''} : $ENV{PWD};

	$leftftp = Net::xFTP->new();
	$localftp = Net::xFTP->new();
		$xfermodeBtnAscii->configure(-state => 'disabled');
		$xfermodeBtnBinary->configure(-state => 'disabled');
		$xfermode = 'binary';
	$useftp = $localftp;
	&rrefreshFn($rdir);
	&lrefreshFn();
}

sub lrefreshFn
{
	$llastknowngooddir = $ldir;
	my $refdir = shift || $ldir || '.';
	$refdir = $ENV{PWD}  if ($refdir eq '.');
	if ($Win32 && $windrive)
	{
		$refdir = $windrive . $refdir  unless ($refdir =~ /\:/o);
	}
	#my @files = getFiles($refdir);
	my @files = $leftftp->dir($refdir, $showall);
	my $hasdot = 0;
	my $hasdotdot = ($refdir eq '/');
	$lfileList->delete('0', 'end');
	@d = ();
	for (my $i=0;$i<=$#files;$i++)
	{
		$d[0] = substr($files[$i],0,1) eq 'd' ? 'd' : ' ';;
		$d[2] = substr($files[$i],0,10);
		$_ = substr($files[$i],11);
		if (/^^[\d\s]*(\S+)\s+(\S+)\s+(\d+)\s+([\d\-]+\s+[\d\:]+)\s+(.+)$/o)
		{
			$d[3] = "$1 $2";
			$d[4] = $3;
			$d[1] = $5;
			$d[5] = $4;
		}
		elsif (/^^[\d\s]*(\S+)\s+(\S+)\s+(\d+)\s+(\w+\s+\d\d?\s+[\d\:]+)\s+(.+)$/o)
		{
			$d[3] = "$1 $2";
			$d[4] = $3;
			$d[1] = $5;
			$d[5] = $4;
		}
		$hasdot = 1  if ($d[1] eq '.');
		$hasdotdot = 1  if ($d[1] eq '..');
		$lfileList->insert('end', [@d]);
	}

	#$lfileList->insert('0', sort(@files));
	$ldir = $refdir;
	$lfileList->insert('0', ['d', '..'])  unless ($hasdotdot);
	$lfileList->insert('0', ['d', '.'])  unless ($hasdot);
	$llastknowngooddir = $ldir;
	&saveLdir();
	return 1;
}

sub saveLdir
{
	my @choicelist = $ldirSel->choices();
	my $alreadythere = 0;
	my @l;
	for (my $i=0;$i<=$#choicelist;$i++)
	{
		if ($choicelist[$i] eq $ldir)
		{
			$alreadythere = 1;
		}
		else
		{
			push (@l, $choicelist[$i]);
		}
	}
	@choicelist = @l;
	unshift (@choicelist, $ldir)  if (-d $ldir);
	if ($maxdirs > 0)
	{
		while ($#choicelist >= $maxdirs)
		{
			pop(@choicelist);
		}
	}
	$ldirSel->choices(\@choicelist);
}

sub rrefreshFn
{
	my @files;
	my $saverdir = $rlastknowngooddir || $rdir;

	$refdir = shift || $rdir || $rlastknowngooddir;
	$refdir = $rdir  if ($refdir =~ /Tk::Entry=HASH/o);
	my $try;
	$refdir ||= $useftp->pwd();
	$refdir = $useftp->pwd()  if ($refdir eq '.');
	#@files = $useftp->dir($refdir)  if ($useftp->isadir($refdir));
	if ($useftp->isadir($refdir))
	{
		@files = $useftp->dir($refdir, $showall);
		my $hasdot = 0;
		my $hasdotdot = ($refdir eq '/');
		$rfileList->delete('0', 'end');
		#$rfileList->insert('0', sort(@files));
		@d = ();
		for (my $i=0;$i<=$#files;$i++)
		{
			$d[0] = substr($files[$i],0,1) eq 'd' ? 'd' : ' ';;
			$d[2] = substr($files[$i],0,10);
			$_ = substr($files[$i],11);
			if (/^[\d\s]*(\S+)\s+(\S+)\s+(\d+)\s+([\d\-]+\s+[\d\:]+)\s+(.+)$/o)
			{
				$d[3] = "$1 $2";
				$d[4] = $3;
				$d[1] = $5;
				$d[5] = $4;
			}
			elsif (/^^[\d\s]*(\S+)\s+(\S+)\s+(\d+)\s+(\w+\s+\d\d?\s+[\d\:]+)\s+(.+)$/o)
			{
				$d[3] = "$1 $2";
				$d[4] = $3;
				$d[1] = $5;
				$d[5] = $4;
			}
			$hasdot = 1  if ($d[1] eq '.');
			$hasdotdot = 1  if ($d[1] eq '..');
			$rfileList->insert('end', [@d]);
		}
		$rdir = $refdir;
		$rfileList->insert('0', ['d', '..'])  unless ($hasdotdot);
		$rfileList->insert('0', ['d', '.'])  unless ($hasdot);
		$lastpath{$remote}->{$remoteuser} = $rdir;
		$rlastknowngooddir = $rdir;
		&saveRdir();
		return 1;
	}
#	else
#	{
#		print STDERR "-($refdir) is NOT a DIR!, returning zero\n";
#	}
	return 0;
}

sub saveRdir
{
	my @choicelist = $rdirSel->choices();
	my $alreadythere = 0;
	my @l;
	for (my $i=0;$i<=$#choicelist;$i++)
	{
		if ($choicelist[$i] eq $rdir)
		{
			$alreadythere = 1;
		}
		else
		{
			push (@l, $choicelist[$i]);
		}
	}
	@choicelist = @l;
	unshift(@choicelist, $rdir);
	if ($maxdirs > 0)
	{
		while ($#choicelist >= $maxdirs)
		{
			pop(@choicelist);
		}
	}
	$rdirSel->choices(\@choicelist);
}

sub lfileClickFn
{
	my ($toType, $todir) = $lfileList->getRow($lfileList->curselection);
	return  unless (defined($lfileList->curselection));
	if ($todir eq '.')
	{
		$todir = $ldir;
		$_ = $ldir;
	}
	elsif ($todir eq '..')
	{
		$_ = $ldir;
		$ldir =~ s#\/([^\/]+?)\/[^\/]+$#\/$1#;
		$ldir = $dirsep  if ($_ eq $ldir);
		$todir = $ldir;
		$_ = $ldir;
	}
	else
	{
		unless ($todir =~ m#^$dirsep#)
		{
			$_ = $ldir;
			$_ .= $dirsep  unless (m#$dirsep$#);
			$_ .= $todir;
			$todir = $_;
		}
	}
	if (-d $todir)
	{
		$ldir = $_;
		&lrefreshFn($todir);
	}
}

sub rfileClickFn
{
	my ($toType, $todir) = $rfileList->getRow($rfileList->curselection);
	if ($todir eq '.')
	{
		$todir = $rdir;
		$_ = $rdir;
	}
	elsif ($todir eq '..')
	{
		$_ = $rdir;
		$rdir =~ s#\/([^\/]+?)\/[^\/]+$#\/$1#;
		$rdir = $dirsep  if ($_ eq $rdir);
		$todir = $rdir;
		$_ = $rdir;
	}
	else
	{
		unless ($todir =~ m#^$dirsep#)
		{
			$_ = $rdir;
			$_ .= $dirsep  unless (m#$dirsep$#);
			$_ .= $todir;
			$todir = $_;
		}
	}
	if ($ftp || -d $todir)
	{
		&rrefreshFn($todir);
	}
}

sub connectFn
{
	if ($ftp)
	{
		$ftp->quit();
#		$sftp = undef;
		&disconnectFn();
	}
	else
	{
		$rememberpswd = 0;
		$remotename = $remote;
		#$remoteuser = '';
		$remotepswd = '';
		$remoteuser = $1  if ($remotename =~ s/\:(.+)$//o);
		$remoteuser = $lastuser{$remote}  if ($lastuser{$remote} =~ /\S/o);
		$remoteuser ||= $prevusers{$remote}->[0]  if ($#{$prevusers{$remote}} >= 0
				&& $prevusers{$remote}->[0] =~ /\S/o);
		$remotepswd = $prevpswds{$remote}->{$remoteuser} || '';
#print "-???- pswd=$remotepswd=\n";
		$rememberpswd = 1  if ($remotepswd);
		$old_grab  = $MainWin->grabSave;
		$remoteuserSel->choices($prevusers{$remote});
		$loginWin->Popup();
		if ($remoteuser)
		{
			$remotepswdEntry->focus();
		}
		else
		{
			$remoteuserSel->focus();
		}
		$loginWin->grab;
	}
}

sub disconnectFn
{
	alarm(0)  unless ($bummer);
	if ($ftp)
	{
		$ftp->quit();
		$xfermodeBtnAscii->configure(-state => 'disabled');
		$xfermodeBtnBinary->configure(-state => 'disabled');
		$xfermode = 'binary';
		$ftp = undef;
		$useftp = $localftp;
	}
	my @choicelist = $remoteuserSel->choices();
	$prevusers{$remote} = [@choicelist];
	@choicelist = $rdirSel->choices();
	$prevpaths{$remote} = [@choicelist];
	$prevpswds{$remote}->{$remoteuser} = $rememberpswd ? $remotepswd : '';
	$lastuser{$remote} = $remoteuser;
	$connectBtn->configure(-text => 'Connect');
#	$sftpCkbtn->configure(-state => 'normal')  if ($haveSFTP);
	$sftpCkbtn->configure(-state => 'normal');
	$rdir = $ENV{PWD};
	&staterr("..Disconnected from remote host \"$remotename\".", 0);
	$remotename = $remote = $localhost;
	&rrefreshFn((-d $lastpath{$localhost}->{''}) ? $lastpath{$localhost}->{''} : $ENV{PWD});
	$remoteSel->configure(-state => 'normal');
	$rdirSel->choices($prevpaths{$localhost}||[]);
	$remoteuser = '';
	$remotepswd = '';
}

sub forceDisconnect
{
	&connectFn();   #DISCONNECT.
	&staterr("..Could NOT open a directory on remote server!", 0);
	$ftp = undef;   #ADDED 20030124.
	$xfermodeBtnAscii->configure(-state => 'disabled');
	$xfermodeBtnBinary->configure(-state => 'disabled');
	$xfermode = 'binary';
	$useftp = $localftp;
	$remoteuser = '';
	#$remote = $localhost;   #ADDED 20030124.
	$connectBtn->configure(-state => 'normal', -text => 'Connect');
}

sub loginOkFn
{
	$loginWin->grabRelease;
	$loginWin->withdraw();
	$connectBtn->configure(-state => 'disabled', -text => 'connecting');
	&$old_grab;
	$MainWin->idletasks();
	$MainWin->Busy();
#	my $protocol = ($usesftp ? 'Net::SFTP' : 'Net::FTP');
	my $protocol =  ($usesftp =~ /\S/o) ? ('Net::'.$usesftp) : '';

#print STDERR "-logging in:  protocol=$protocol= host=$remotename= debug=$d= user=$remoteuser= pswd=$remotepswd=\n";
#	$ftp = Net::xFTP->new($protocol, $remotename, Debug => ($d ? 1 : 0),
#			user => $remoteuser, password => $remotepswd);

	#FOR SOME STUPID REASON, SOME SFTP SERVERS & SFTP FUNCTIONS WILL NOT TAKE ARGUMENTS 
	#IN VARIABLES POPULATED BY TK (TAINTED/ENCODED SOMEHOW)?  BUT I FOUND A WORKAROUND 
	#BY FIRST PLACING THE FUNCTION AND IT'S ARGS IN AN EVAL STRING & EVALLING IT?!?!?!?!
	#THE ERROR RETURNED IS:  
	#"input must be 8 bytes long at /usr/local/lib/perl/5.8.7/Crypt/DES.pm line 66."
	#THE FUNCTIONS THAT ARE KNOWN TO FAIL ARE IN THE VARIABLE "evalStr".

	my $evalStr = "Net::xFTP->new('$protocol', '$remotename', Debug => ".($d ? 1 : 0).", user => '$remoteuser', password => '$remotepswd');";
	$ftp = eval $evalStr;
	unless ($ftp)
	{
		my $errmsg = $@;
		$MainWin->Unbusy();
		$ftp = undef;   #ADDED 20030124.
		$xfermodeBtnAscii->configure(-state => 'disabled');
		$xfermodeBtnBinary->configure(-state => 'disabled');
		$xfermode = 'binary';
		$useftp = $localftp;
		$remoteuser = '';
		#$remote = $localhost;   #ADDED 20030124.
		$connectBtn->configure(-state => 'normal', -text => 'Connect');
		return &staterr("Could not connect to remote host \"$remotename\" ($errmsg)!", 1);
	}
	if ($protocol eq 'Net::FTP')  #CURRENTLY ONLY FTP SUPPORTS ASCII (VS BINARY)!
	{
		$xfermodeBtnAscii->configure(-state => 'normal');
		$xfermodeBtnBinary->configure(-state => 'normal');
	}
	else
	{
		$xfermodeBtnAscii->configure(-state => 'disabled');
		$xfermodeBtnBinary->configure(-state => 'disabled');
		$xfermode = 'binary';
	}
	$useftp = $ftp;
	alarm(119)  if ($keepopen);
	$MainWin->Unbusy();
	$rdirSel->choices($prevpaths{$remote}||[]);
	my $maxcnt = 25;
	my $isaDir = 0;
	while (1)
	{
		$isaDir = &rrefreshFn($lastpath{$remote}->{$remoteuser}||'.');
		last  if (!length($lastpath{$remote}->{$remoteuser}) || $isaDir);
		$lastpath{$remote}->{$remoteuser} =~ s#\/[^\/]*$##;
		last  if ($lastpath{$remote}->{$remoteuser} eq '/');
		last  if (--$maxcnt < 0);   #MAKE ABSOLUTELY SURE WE DON'T HAVE AN INFINATE LOOP!
	}
	unless ($isaDir)
	{
		&forceDisconnect();
		return 0;
	}
	$connectBtn->configure(-state => 'normal', -text => 'Disonnect');
	$prevsftp{$remote} = $usesftp;
	$prevkeep{$remote} = $keepopen;
	$sftpCkbtn->configure(-state => 'disabled');
	my $myremote = $remote;
	$remote = '';

	my @choicelist = $remoteuserSel->choices();
	my $alreadythere = 0;
	for (my $i=0;$i<=$#choicelist;$i++)
	{
		if ($choicelist[$i] eq $remoteuser)
		{
			$alreadythere = 1;
			last;
		}
	}
	unless ($alreadythere)
	{
		unshift (@choicelist, $remoteuser);
		$remoteuserSel->choices(\@choicelist);
	}

	$alreadythere = 0;
	@choicelist = $remoteSel->choices();
	&staterr("..Successfully connected to remote host \"$remotename\".", 0);

	for (my $i=0;$i<=$#choicelist;$i++)
	{
		$_ = $choicelist[$i];
		if ($myremote eq $_)
		{
			$alreadythere = 1;
			last;
		}
	}
	unless ($alreadythere)
	{
		unshift (@choicelist, $myremote);
		$remoteSel->choices(\@choicelist);
	}
	$remoteSel->configure(-state => 'normal');
	$remoteSel->configure(-state => 'disabled');

	$remote = $myremote;
}

sub loginCanFn
{
	$loginWin->grabRelease;
	$loginWin->withdraw();
	&$old_grab;
	$remoteuser = '';
	$ftp = undef;   #ADDED 20030124.
#	$sftp = undef;   #ADDED 20030124.
		$xfermodeBtnAscii->configure(-state => 'disabled');
		$xfermodeBtnBinary->configure(-state => 'disabled');
		$xfermode = 'binary';
	$useftp = $localftp;
}

sub getFiles
{
	my ($dir, $wildcard) = @_;

	#opendir DIR, $dir || return (&staterr("Could not open directory \"$dir\" ($? $!)!", 1));

	#my @files = readdir(DIR);
	
	my @files;
	my $t;
	my @d = $showall ? `ls -la $dir` : `ls -l $dir`;
	if (@d)
	{
		shift @d  if ($d[0] =~ /^total \d/o);   #REMOVE "TOTAL" LINE.
		foreach my $t (@d)
		{
			chomp $t;
			next  if ($t =~ /\d \.\.$/o && $dir eq '/');
			next  if (!$showall && $t =~ /\d \.[^\.]\S*$/o);
			push (@files, $t);
		}
		
	}
	return @files;
}

sub staterr
{
	my $statusmsg = shift;
	my $popup = shift;

	$statusText->insert('end',"\n$statusmsg");
	$statusText->see('end');
	print staterr "$statusmsg\n";
	if ($popup)
	{
		$DIALOG->configure(
				-text => $statusmsg);
		$DIALOG->Show();
	}
	&forceDisconnect()  if ($statusmsg =~ /Connection\s+closed/io);
	return 0;
}

sub uploadFn
{
	my @files2move = $lfileList->curselection;
	my @filenames2move;

	return &staterr('Must select 1 or more files from LEFT list to upload!', 1)
			unless ($#files2move >= 0);
	my $dirprefix = $ldir;
	$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);
	my $t;
	for (my $i=0;$i<=$#files2move;$i++)
	{
		($t, $filenames2move[$i]) = $lfileList->getRow($files2move[$i]);
		$files2move[$i] = $dirprefix . $filenames2move[$i];
	}

	$DIALOG2->configure(
			-text => "Upload following files from Local (left):\n\n"
					.join("\n", @filenames2move)."\n\nAre you SURE?");
	my ($usrres) = $DIALOG2->Show();
	return 0  if $usrres ne $OK;

	$dirprefix = $rdir;
	$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);

	$downloadBtn->configure(-state => 'disabled');
	$uploadBtn->configure(-state => 'disabled');
	#$MainWin->update();
	$MainWin->idletasks();
	$MainWin->Busy();
	my $totalsize = 0;
	my $evalStr;
		#$useftp->type($xfermode) || &staterr("w:COULD NOT SET TRASFER TYPE TO \"$xfermode\" ($@)!", 1);
		if ($xfermode eq 'ascii')
		{
			eval { $useftp->ascii(); };
			&staterr("w:COULD NOT SET TRASFER TYPE TO \"$xfermode\" ($@)!", 1)  if ($@);
		}
		elsif ($xfermode eq 'binary')
		{
			eval { $useftp->binary(); };
			&staterr("w:COULD NOT SET TRASFER TYPE TO \"$xfermode\" ($@)!", 1)  if ($@);
		}
		for (my $i=0;$i<=$#files2move;$i++)
		{
			if (-d $files2move[$i])
			{
				&staterr("w:COULD NOT UPLOAD \"$files2move[$i]\" - it is a DIRECTORY!", 1);
			}
			else
			{
#				if ($useftp->put($files2move[$i], "${dirprefix}$filenames2move[$i]"))
				$evalStr = "\$useftp->put('$files2move[$i]', '${dirprefix}$filenames2move[$i]')";
				if (eval $evalStr)
				{
					$lastsize = $useftp->size("${dirprefix}$filenames2move[$i]");
					$totalsize += $lastsize;
					&staterr("..Uploaded \"$files2move[$i]\"; ($lastsize bytes to \"${dirprefix}$filenames2move[$i]\").", 0);
				}
				else
				{
					&staterr("w:COULD NOT UPLOAD \"$files2move[$i]\" to \"${dirprefix}$filenames2move[$i]\" ("
							.$useftp->message().")!", 1);
				}
			}
		}
	$MainWin->Unbusy();
	$lfileList->selectionClear(0, 'end');
	&staterr("..Uploaded ".&commatize($totalsize)." bytes total to $remote.", 0)  if ($totalsize);
	&rrefreshFn();
	$downloadBtn->configure(-state => 'normal');
	$uploadBtn->configure(-state => 'normal');
}

sub downloadFn
{
	my @files2move = $rfileList->curselection;
	my @filenames2move;

	#return 0  unless ($#files2move >= 0);
	return &staterr('Must select 1 or more files from RIGHT list to download!', 1)
			unless ($#files2move >= 0);
	my $dirprefix = $rdir;
	$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);
	my $t;
	for (my $i=0;$i<=$#files2move;$i++)
	{
		($t, $filenames2move[$i]) = $rfileList->getRow($files2move[$i]);
		$files2move[$i] = $dirprefix . $filenames2move[$i];
	}

	$DIALOG2->configure(
			-text => "Download following files from \"$remotename\" (right):\n\n"
					.join("\n", @filenames2move)."\n\nAre you SURE?");
	my ($usrres) = $DIALOG2->Show();
	return 0  if $usrres ne $OK;

	$dirprefix = $ldir;
	$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);

	$downloadBtn->configure(-state => 'disabled');
	$uploadBtn->configure(-state => 'disabled');
	#$MainWin->update();
	$MainWin->idletasks();
	$MainWin->Busy();
	my $totalsize = 0;
		if ($xfermode eq 'ascii')
		{
			eval { $useftp->ascii(); };
			&staterr("w:COULD NOT SET TRASFER TYPE TO \"$xfermode\" ($@)!", 1)  if ($@);
		}
		elsif ($xfermode eq 'binary')
		{
			eval { $useftp->binary(); };
			&staterr("w:COULD NOT SET TRASFER TYPE TO \"$xfermode\" ($@)!", 1)  if ($@);
		}
		for (my $i=0;$i<=$#files2move;$i++)
		{
			if ($useftp->get($files2move[$i], "${dirprefix}$filenames2move[$i]"))
			{
				$lastsize = $useftp->size($files2move[$i]);
				$totalsize += $lastsize;
				&staterr("..Downloaded \"$files2move[$i]\"; ($lastsize bytes to \"${dirprefix}$filenames2move[$i]\").", 0);
			}
			else
			{
				&staterr("w:COULD NOT DOWNLOAD \"$files2move[$i]\" to \"${dirprefix}$filenames2move[$i]\" ("
						.$useftp->message().")!", 1);
			}
		}
	$MainWin->Unbusy();
	$rfileList->selectionClear(0, 'end');
	&staterr("..Downloaded ".&commatize($totalsize)." bytes total from $remote.", 0)  if ($totalsize);
	&lrefreshFn();
	$uploadBtn->configure(-state => 'normal');
	$downloadBtn->configure(-state => 'normal');
}

sub lmkdirFn
{
	my $olddir = $ldir;
	$olddir = $1  if ($ldir =~ m#(.*?)\/[^\/]+$#);
	eval {`mkdir $ldir` };
	if ($?)
	{
		&staterr("w:COULD NOT CREATE DIRECTORY \"$ldir\" ($?)!", 1);
		$ldir = $olddir;
		&lrefreshFn($olddir);
	}
	else
	{
		&staterr("..Created directory \"$ldir\".", 0);
		$ldir = $olddir;
		&lrefreshFn($olddir);
		return 1;
	}
	return 0;
}

sub rmkdirFn
{
	$olddir = $1  if ($rdir =~ m#(.*?)\/[^\/]+$#);
	$res = 0;
	$res = $useftp->mkdir($rdir, 1);
	if ($res)
	{
		&staterr("..Created remote directory \"$rdir\".", 0);
		$rdir = $olddir;
		&rrefreshFn($olddir);
		return 1;
	}
	else
	{
		&staterr("w:COULD NOT CREATE REMOTE DIRECTORY \"$rdir\" ("
				.$useftp->message().")!", 1);
		$rdir = $olddir;
		&rrefreshFn($olddir);
	}
	return 0;
}

sub lrmdirFn
{
	my $olddir = $ldir;
	$olddir = $1  if ($ldir =~ m#(.*?)\/[^\/]+$#);
	$DIALOG2->configure(
			-text => "DELETE subdirectory \"$ldir\" from Local (left):\n\nAre you SURE?");
	my ($usrres) = $DIALOG2->Show();
	return 0  if $usrres ne $OK;

	eval {`rmdir $ldir` };
	if ($?)
	{
		&staterr("w:COULD NOT REMOVE DIRECTORY \"$ldir\" ("
				.($?||'Not Empty?').")!", 1);
		$ldir = $olddir;
		&lrefreshFn($olddir);
	}
	else
	{
		&staterr("..REMOVED directory \"$ldir\".", 0);
		$ldir = $olddir;
		&lrefreshFn($olddir);
		return 1;
	}
	return 0;
}

sub rrmdirFn
{
	$olddir = $1  if ($rdir =~ m#(.*?)\/[^\/]+$#);
	$DIALOG2->configure(
			-text => "DELETE subdirectory \"$rdir\" from \"$remotename\" (right):\n\nAre you SURE?");
	my ($usrres) = $DIALOG2->Show();
	return 0  if $usrres ne $OK;

	$res = 0;
	$res = $useftp->rmdir($rdir);
	if ($res)
	{
		&staterr("..REMOVED remote directory \"$rdir\".", 0);
		$rdir = $olddir;
		&rrefreshFn($olddir);
		return 1;
	}
	else
	{
		&staterr("w:COULD NOT REMOVE REMOTE DIRECTORY \"$rdir\" ("
				.($useftp->message()||'Not Empty?').')!', 1);
		$rdir = $olddir;
		&rrefreshFn($olddir);
	}
	return 0;
}

sub lshowsizeFn
{
	my @files = $lfileList->curselection;
	my @filenames;
	my $dirprefix = $ldir;
	$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);
	my $header;
	my $t;
	if ($#files >= 0)
	{
		for (my $i=0;$i<=$#files;$i++)
		{
			($t, $filenames[$i]) = $lfileList->getRow($files[$i]);
			$files[$i] = $dirprefix . $filenames[$i];
		}
		$header = 'selected';
	}
	else
	{
		@filenames = $lfileList->get(0, 'end');
		for (my $i=0;$i<=$#filenames;$i++)
		{
			$files[$i] = $dirprefix . $filenames[$i]->[1];
		}
		$header = 'all listed';
	}
	my $totalsize = 0;
	for (my $i=0;$i<=$#files;$i++)
	{
		unless (-d $files[$i])
		{
			(undef, undef, undef, undef, undef, undef, undef, $lastsize)
					= stat($files[$i]);
			$totalsize += $lastsize;
		}
	}
	&staterr("..Total size of $header files in left list is ".&commatize($totalsize)." bytes.", 0);
	return 1;
}

sub rshowsizeFn
{
	my @files = $rfileList->curselection;
	my @filenames;
	my $dirprefix = $rdir;
	$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);
	my $header;
	my $t;
	if ($#files >= 0)
	{
		for (my $i=0;$i<=$#files;$i++)
		{
			($t, $filenames[$i]) = $rfileList->getRow($files[$i]);
			$files[$i] = $dirprefix . $filenames[$i];
		}
		$header = 'selected';
	}
	else
	{
		@filenames = $rfileList->get(0, 'end');
		for (my $i=0;$i<=$#filenames;$i++)
		{
			$files[$i] = $dirprefix . $filenames[$i]->[1];
		}
		$header = 'all listed';
	}
	my $totalsize = 0;
	for (my $i=0;$i<=$#files;$i++)
	{
		unless ($useftp->isadir($files[$i]))
		{
			$lastsize = $useftp->size($files[$i]);
			$totalsize += $lastsize;
		}
	}
	&staterr("..Total size of $header files in right list is ".&commatize($totalsize)." bytes.", 0);
	return 1;
}

sub ldeleteFn
{
	my @files2move = $lfileList->curselection;
	my @filenames2move;

	return 0  unless ($#files2move >= 0);

	my $dirprefix = $ldir;
	$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);
	my $t;
	for (my $i=0;$i<=$#files2move;$i++)
	{
		($t, $files2move[$i]) = $lfileList->getRow($files2move[$i]);
	}
	$DIALOG2->configure(
			-text => "DELETE following files from Local (left):\n\n"
					.join("\n", @files2move)."\n\nAre you SURE?");
	my ($usrres) = $DIALOG2->Show();
	return 0  if $usrres ne $OK;

	for (my $i=0;$i<=$#files2move;$i++)
	{
		$files2move[$i] = $dirprefix . $files2move[$i];
		if (unlink($files2move[$i]))
		{
			&staterr("..deleted \"$files2move[$i]\"!", 0);
		}
		else
		{
			&staterr("w:COULD NOT DELETE \"$files2move[$i]\" ($? $! $@)!", 1);
		}
	}
	&lrefreshFn();
}

sub rdeleteFn
{
	my @files2move = $rfileList->curselection;
	my @filenames2move;

	return 0  unless ($#files2move >= 0);

	my $t;
	for (my $i=0;$i<=$#files2move;$i++)
	{
		($t, $files2move[$i]) = $rfileList->getRow($files2move[$i]);
	}
	$DIALOG2->configure(
			-text => "DELETE following files from \"$remotename\" (right):\n\n"
					.join("\n", @files2move)."\n\nAre you SURE?");
	my ($usrres) = $DIALOG2->Show();
	return 0  if $usrres ne $OK;

	my $dirprefix = $rdir;
	$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);
	for (my $i=0;$i<=$#files2move;$i++)
	{
		$files2move[$i] = $dirprefix . $files2move[$i];
		$res = 0;
		$res = $useftp->delete($files2move[$i]);
		if ($res)
		{
			&staterr("..DELETED remote file: \"$files2move[$i]\".", 0);
		}
		else
		{
			&staterr("w:COULD NOT DELETE remote file: \"$files2move[$i]\" ("
					.$useftp->message().")!", 1);
		}
	}
	&rrefreshFn();
}

sub lrenameFn
{
	my @files2move = $lfileList->curselection;
	my @filenames2move;
	$activeside = 'l';

	my $t;
	unless ($#files2move >= 0)
	{
		return &staterr('w:Must select a file from the LEFT-side list to rename!', 1);
	}
	&staterr('w:More than 1 file selected from (left) list, only FIRST file renamed!', 1) 
			if ($#files2move);
	my $dirprefix = $rdir;
	$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);
	($t, $oldname) = $lfileList->getRow($files2move[0]);
	$newname = '';
	$old_grab  = $MainWin->grabSave;
	$renameWin->Popup();
	$newnameEntry->focus();
}

sub rrenameFn
{
	my @files2move = $rfileList->curselection;
	my @filenames2move;
	$activeside = 'r';

	my $t;
	unless ($#files2move >= 0)
	{
		return &staterr('w:Must select a file from the RIGHT-side list to rename!', 1);
	}
	&staterr('w:More than 1 file selected from (right) list, only FIRST file renamed!', 1) 
			if ($#files2move);
	my $dirprefix = $rdir;
	$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);
	($t, $oldname) = $rfileList->getRow($files2move[0]);
	$newname = '';
	$old_grab  = $MainWin->grabSave;
	$renameWin->Popup();
	$newnameEntry->focus();
}

sub renameOkFn
{
	$renameWin->grabRelease;
	$renameWin->withdraw();
	&$old_grab;

	my $dirprefix;
	if ($activeside eq 'r')
	{
		$dirprefix = $rdir;
		$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);
		if ($useftp->rename("${dirprefix}$oldname", "${dirprefix}$newname"))
		{
			$lastsize = $useftp->size($files2move[$i]);
			$totalsize += $lastsize;
			&staterr("..Renamed \"$oldname\" to \"$newname\" in right list.", 0);
		}
		else
		{
			&staterr("w:COULD NOT RENAME \"${dirprefix}$oldname\" to \"${dirprefix}$newname\" ("
					.$useftp->message().")!", 1);
		}
		$rfileList->see($rfileList->curselection);
		&rrefreshFn($rdir);
	}
	else
	{
		$dirprefix = $ldir;
		$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);
		if (rename("${dirprefix}$oldname", "${dirprefix}$newname"))
		{
			&staterr("..Renamed \"$oldname\" to \"$newname\" in left list.", 0);
		}
		else
		{
			&staterr("w:COULD NOT RENAME \"${dirprefix}$oldname\" to \"${dirprefix}$newname\" ($!)!", 1);
		}
		$lfileList->see($lfileList->curselection);
		&lrefreshFn($ldir);
	}
}

sub renameCanFn
{
	$renameWin->grabRelease;
	$renameWin->withdraw();
	&$old_grab;
}

sub lviewFn
{
	my $editing = shift;
	my @files2move = $lfileList->curselection;
	my $myproc = $editing ? $editor : $viewer;
	my $eorv = $editing ? 'editing' : 'viewing';
	&staterr("..Opening left-side file ($filename) for $eorv!\n", 0);

	unless ($#files2move >= 0)
	{
		return &staterr('w:Must select a file from the LEFT-side list to view!', 1);
	}
	if ($#files2move)
	{
		&staterr('w:More than 1 file selected from (left) list, only FIRST file used!', 1);
		return 0  if ($editing);
	}
	my ($t, $filename) = $lfileList->getRow($files2move[0]);

	my $dirprefix = $ldir;
	$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);
	$myproc =~ s/\%r/Local/o;
	system ($myproc, "${dirprefix}$filename");
	return "${dirprefix}$filename";
}

sub rviewFn
{
	my $editing = shift;
	my @files2move = $rfileList->curselection;
	my $myproc = $editing ? $editor : $viewer;

	unless ($#files2move >= 0)
	{
		return &staterr('w:Must select a file from the RIGHT-side list to view!', 1);
	}
	if ($#files2move)
	{
		&staterr('w:More than 1 file selected from (right) list, only FIRST file used!', 1);
		return 0  if ($editing);
	}
	my ($t, $filename) = $rfileList->getRow($files2move[0]);

	my $dirprefix = $rdir;
	$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);
	my $eorv = $editing ? 'editing' : 'viewing';
	&staterr("..Opening right-side file ($filename) for $eorv!\n", 0);
	if ($ftp)
	{
		if ($ftp->get("${dirprefix}$filename", "$ENV{HOME}/.ptkftp.tmp"))
		{
			if ($editing)
			{
				my $savekeepopen = $keepopen;
				$keepopen = 1;
				alarm(119)  unless ($bummer);
				$MainWin->idletasks();
				$MainWin->Busy();
				`$editor $ENV{HOME}/.ptkftp.tmp`;
				if ($@)
				{
					&staterr("w:May have had trouble with editor ($editor): ($@)!", 1);
				}
				$keepopen = $savekeepopen;
				$MainWin->Unbusy();
			}
			else
			{
				my $myproc = $viewer;
				$myproc =~ s/\%r/Remote/o;
				system ($viewer, "$ENV{HOME}/.ptkftp.tmp");
				if ($?)
				{
					&staterr("e:Could not invoke viewer ($viewer) ($?)!", 1);
					return 0;
				}
			}
			unlink ("ENV{HOME}/.ptkftp.tmp")  unless ($editing);
		}
		else
		{
			&staterr("w:COULD NOT FETCH \"${dirprefix}$filename\" ("
					.$ftp->message().")!", 1);
		}
	}
	else
	{
		$myproc =~ s/\%r/Remote/o;
		system ($myproc, "${dirprefix}$filename");
		if ($?)
		{
			&staterr("e:Could not invoke editor/viewer ($myproc) ($?)!", 1);
			return 0;
		}
	}
	return "${dirprefix}$filename";
}

sub leditFn
{
	&staterr("..Updated local file \"$filename\" (left side)!", 0);
	return &lviewFn(1) ? 1 : 0;
}

sub reditFn
{
	my $filename = &rviewFn(1);
	if ($filename)
	{
		if ($ftp)
		{
			my $evalStr = "\$ftp->put('$ENV{HOME}/.ptkftp.tmp', '$filename')";
			if (eval $evalStr)
			{
				$lastsize = $ftp->size($filename);
				&staterr("..Replaced remote file \"$filename\" with updated version ($lastsize bytes)!", 0);
				unlink ("ENV{HOME}/.ptkftp.tmp");
			}
			else
			{
				return &staterr("w:COULD NOT REPLACE \"$filename\" after editing ($res:".$ftp->message().")!", 1);
			}
		}
		else
		{
			&staterr("..Updated local file \"$filename\" (right side)!", 0);
		}
		return 1;
	}
	return 0;
}

sub diffFn
{
	my @lfile = $lfileList->curselection;
	my @rfile = $rfileList->curselection;

	unless (!$#lfile && !$#rfile)
	{
		return &staterr('w:Must select 1 file from both lists to compare!', 1);
	}
	my ($t, $lfilename) = $lfileList->getRow($lfile[0]);
	my $rfilename;
	($t, $rfilename) = $rfileList->getRow($rfile[0]);

	my $dirprefix = $ldir;
	$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);
	$lfilename = $dirprefix . $lfilename;

	$dirprefix = $rdir;
	$dirprefix .= $dirsep  unless ($dirprefix =~ m#$dirsep$#);
	$rfilename = $dirprefix . $rfilename;

	my $diffexec = $diffcmd;
	$diffexec .= ' %1'  unless ($diffcmd =~ /\%1/o);
	$diffexec .= ' %2'  unless ($diffcmd =~ /\%2/o);
	if ($ftp)
	{
		if ($ftp->get($rfilename, "$ENV{HOME}/.ptkftp.tmp"))
		{
			#system ("$diffcmd $lfilename $ENV{HOME}/.ptkftp.tmp &");
			$diffexec =~ s/\%1/$lfilename/g;
			$diffexec =~ s#\%2#$ENV{HOME}/.ptkftp.tmp#g;
			$diffexec .= '&'  unless ($diffexec =~ /\&\s*$/o);
			`$diffexec`;
			if ($@)
			{
				&staterr("e:Could not invoke diff cmd ($diffcmd) ($@)!", 1);
				return 0;
			}
			unlink ("ENV{HOME}/.ptkftp.tmp");
		}
		else
		{
			&staterr("w:COULD NOT FETCH \"$rfilename\" for comparisen("
					.$ftp->message().")!", 1);
		}
	}
	else
	{
		#system ("$diffcmd $lfilename $rfilename");
		$diffexec =~ s/\%1/$lfilename/g;
		$diffexec =~ s/\%2/$rfilename/g;
		$diffexec .= '&'  unless ($diffexec =~ /\&\s*$/o);
		`$diffexec`;
		if ($@)
		{
			&staterr("e:Could not invoke diff cmd ($diffcmd) ($@)!", 1);
			return 0;
		}
		unlink ("ENV{HOME}/.ptkftp.tmp")  unless ($editing);
	}
}

sub callback
{
	my($sftp, $data, $offset, $size) = @_;
	$lastsize = $size || '0';
}

sub About
{
	my $aboutText = <<END_TEXT;
$headTitle
(c) 2002 - 2007
by:  Jim Turner
All rights reserved

END_TEXT
	my $aboutDialog = $MainWin->JDialog(
			-title          => $headTitle,
			-text           => $aboutText,
			-bitmap         => 'info',
			-default_button => $OK,
			-escape_button  => $OK,
			-buttons        => [$OK ],
	);
	$aboutDialog->Show();
}

sub commatize
{
	my ($val) = shift;

	$val = sprintf('%.0f',$val);
	$val =~ s/(\d)(\d\d\d)$/$1,$2/;
	$val =~ s/(\d)(\d\d\d),/$1,$2,/g;
	return ("$val");
}

sub exitFn
{
	if (open(F, ">$ENV{HOME}/.ptkftp.prev"))
	{
		print F "$maxdirs\n$haveCrypt\n";
		print F "$editor|$viewer|$diffcmd\n";
		open(G, ">$ENV{HOME}/.ptkftp.users")  if ($CBC);
		@prevhosts = sort $remoteSel->choices();
		@{$prevpaths{$localhost}} = $ldirSel->choices();
		my (@l, @l2, $t);
		while (@prevhosts)
		{
			@l = @l2 = ();
			$_ = shift(@prevhosts);
			foreach my $i (@{$prevusers{$_}})
			{
				$t = '';
				for (my $jj=length($prevpswds{$_}->{$i});$jj<8;$jj++)   #ADDED 20040101 TO FIX STUPID DES ERROR.
				{
					$prevpswds{$_}->{$i} .= ' ';
				}
				$t = $CBC->encrypt($prevpswds{$_}->{$i})  if ($CBC);
				$t =~ s/\n/\<LF\>/gso;
				$t =~ s/\0/\<NULL\>/go;
				push (@l, $t);
				push (@l2, $lastpath{$_}->{$i})
			}
			@l2 = ($lastpath{$_}->{''})  unless ($#l2 >= 0);
			if ($_ =~ /\S/)
			{
				print F "$_|".join(',', @{$prevusers{$_}}).'|'
						.join(',', @{$prevpaths{$_}}).'|'.join(':', @l2).'|'
						.$lastuser{$_}."|$prevsftp{$_}|$prevkeep{$_}\n";
				print G "$_|"		.join("<BR>", @l)."\n"  if ($CBC);
			}
		}
		close G if ($CBC);
		close F;
	}
	exit(0);
}

sub lchmodFn
{
	$activeside = 'l';
	$old_grab  = $MainWin->grabSave;
	$chmodWin->Popup();
	$chmodEntry->focus();
}

sub rchmodFn
{
	$activeside = 'r';
	$old_grab  = $MainWin->grabSave;
	$chmodWin->Popup();
	$chmodEntry->focus();
}

sub chmodOkFn
{
	unless ($chmodValue =~ /^[0-7][0-7][0-7][0-7]?$/o)
	{
		$DIALOG->configure(
				-text => "Invalid Permissions - must be 3 or 4 octal digits (0-7)!");
		$DIALOG->Show();
		return 0;
	}

	$chmodWin->grabRelease;
	$chmodWin->withdraw();
	&$old_grab;

	my @files2chmod;
	my ($t, $mydir, $myfilelist, $myhostMsg, $fid, @fids2chmod, @fileNames2chmod);

	if ($activeside eq 'r')
	{
		$mydir = $rdir;
		$myfileList = $rfileList;
		$myhostMsg = "\"$remotename\" (right)";
	}
	else
	{
		$mydir = $ldir;
		$myfileList = $lfileList;
		$myhostMsg = "local (left)";
	}
	@files2chmod = $myfileList->curselection;
	my $evalStr;
	if (@files2chmod)
	{
		for (my $i=0;$i<=$#files2chmod;$i++)
		{
			($t, $fid) = $myfileList->getRow($files2chmod[$i]);
			push (@fileNames2chmod, $fid);
			$fid = $mydir . '/' . $fid;
			$fid =~ s#\/\/#\/#o;
			push (@fids2chmod, $fid);
		}
		$DIALOG2->configure(
				-text => "CHMOD following files on $myhostMsg to $chmodValue:\n\n"
				.join("\n", @fileNames2chmod)."\n\nAre you SURE?");
		my ($usrres) = $DIALOG2->Show();
		return 0  if $usrres ne $OK;

		for (my $i=0;$i<=$#fids2chmod;$i++)
		{
			$evalStr = "\$useftp->chmod('$chmodValue', '$fids2chmod[$i]')";
			eval($evalStr) ?
				&staterr("..Changed permissions to $chmodValue on file: \"$fids2chmod[$i]\".", 0)
				: &staterr("w:COULD NOT CHANGE PERMISSIONS TO $chmodValue on \"$fids2chmod[$i]\" ("
				. $useftp->message().'!', 1)
		}
	}
	else
	{
		$DIALOG2->configure(
				-text => "CHMOD DIRECTORY \"$mydir\" on $myhostMsg to $chmodValue:\n\n"
				.join("\n", @files2chmod)."\n\nAre you SURE?");
		my ($usrres) = $DIALOG2->Show();
		return 0  if $usrres ne $OK;
		$evalStr = "\$useftp->chmod('$chmodValue', '$mydir')";
		eval($evalStr) ?
				&staterr("..Changed permissions to $chmodValue on directory: $mydir.", 0)
				: &staterr("w:COULD NOT CHANGE PERMISSIONS TO $chmodValue on directory: $mydir ("
				. $useftp->message().'!', 1)
	}
	if ($activeside eq 'r')
	{
		&rrefreshFn();
	}
	else
	{
		&lrefreshFn();
	}
}

sub chmodCanFn
{
	$chmodWin->grabRelease;
	$chmodWin->withdraw();
	&$old_grab;
}

sub setTheme
{
	my ($bg, $fg, $c, $font);
	eval $themeHash{$_[0]};
	my $fgisblack;
	$fgisblack = 1  if ($fg =~ /black/io); #KLUDGE SINCE SETPALETTE/SUPERTEXT BROKE!
	if ($c)
	{
		$MainWin->setPalette($c);
	}
	else
	{
		eval { $MainWin->optionReadfile('~/.Xdefaults') or $MainWin->optionReadfile('/etc/Xdefaults'); };
		$c = $MainWin->optionGet('tkPalette','*');
		$MainWin->setPalette($c)  if ($c);
	}
	#&setFont($font)  if ($font =~ /\d/);
}

__END__
