package GenEPUB;
# by Masahiko OHKUBO <http://remoteroom.jp> <http://twitter.com/mah_jp>

use strict;
use warnings;
use utf8;

use CGI; $CGI::POST_MAX = 10 * 1048576; # MegaBytes
use CGI::Carp qw(fatalsToBrowser);
use CGI::Application; # cpanm
use base qw(CGI::Application);
use CGI::Application::Plugin::Config::Simple; # cpanm
use CGI::Application::Plugin::DBH qw(dbh_config dbh); # cpanm
use CGI::Application::Plugin::Forward; # cpanm
use CGI::Application::Plugin::JSON ':all'; # cpam
use CGI::Application::Plugin::Redirect; # cpanm
use CGI::Application::Plugin::Session; # cpanm
use HTML::Template::Pro; # cpanm
use DBI; # cpanm
use DBD::mysql; # cpanm
use Storable; # cpanm

sub cgiapp_init {
	my $self = shift;
	$self->query->charset('utf-8');
	$self->config_file($self->param('config_file'));
	$self->dbh_config($self->config_param('database.dsn'), $self->config_param('database.user'), $self->config_param('database.password'));
	my($cookie_path, $cookie_secure);
	$cookie_path = substr($ENV{'SCRIPT_NAME'}, 0, rindex($ENV{'SCRIPT_NAME'}, '/')) . '/';
	if ($ENV{'HTTPS'}) {
		$cookie_secure = 1;
	} else {
		$cookie_secure = 0;
	}
	my $sid = $self->query->param('CGISESSID') || $self->query->cookie('CGISESSID') || undef; # http://www.dab.hi-ho.ne.jp/sasa/biboroku/perl/session.html
	$self->session_config(
#		CGI_SESSION_OPTIONS => [ $self->config_param('database.cgi_session_dsn'), $self->query, { Handle => $self->dbh } ],
		CGI_SESSION_OPTIONS => [ $self->config_param('database.cgi_session_dsn'), $sid, { Handle => $self->dbh } ],
		DEFAULT_EXPIRY => '+' . $self->config_param('system.expire_session_min') . 'm',
 		COOKIE_PARAMS => { -expires => '', -path => $cookie_path, -secure => $cookie_secure },
		SEND_COOKIE => 1,
	);
	$self->header_add( -type => 'text/html; charset=UTF-8' );
	$self->tmpl_path($self->param('template_dir'));
	# query with CGISESSID
	if ($self->query->param('CGISESSID')) {
#		if (($ENV{'HTTPS'}) && ($self->query->param('mode'))) {
		if ($self->query->param('mode')) {
			if ($self->query->param('mode') ne 'download') {
				$self->session_cookie;
				$self->session_recreate;
				return $self->redirect(&url_https($self) . '?mode=' . $self->query->param('mode'));
			}
		} else {
			$self->session_delete;
			return $self->redirect(&url_now());
		}
	}
	return;
}

sub setup {
	my $self = shift;
	$self->mode_param('mode');
	$self->error_mode('mode_status');
	$self->start_mode('edit');
	$self->run_modes(
		'edit'      => \&mode_edit,
		'make'      => \&mode_make,
		'preview'   => \&mode_preview,
		'download'  => \&mode_download,
		'api'       => \&mode_make,
		'status'    => \&mode_status,
		'cleanup'   => \&mode_cleanup,
		'ad'        => \&mode_ad,
		'mail'      => \&mode_mail,
		'click'     => \&mode_click,
	);
}

sub html_tmpl_class { 'HTML::Template::Pro' }

sub mode_edit {
	eval 'use Encode';
	eval 'use Encode::Guess qw(iso-2022-jp cp932 euc-jp)';
	my $self = shift;
	$self = &set_query2session($self);
	$self->session->param('login' => 1);
	my($flag_form);
	if (defined($self->query->param('mode')) && ($self->query->param('mode') eq 'edit')) {
		$flag_form = 1;
	}
	my $tmpl_obj = $self->load_tmpl('edit.tmpl', case_sensitive => 1, default_escape => 'html');
	$tmpl_obj->param(
		MODE_EDIT => 1,
		&set_tmpl($self),
		TITLE => '',
		#
		FLAG_FORM => $flag_form,
		SESSION_BODY => $self->session->param('body'),
		SESSION_BODYINPUT => $self->session->param('bodyinput'),
			'SESSION_BODYINPUT_' . uc($self->session->param('bodyinput')) => 'yes',
		SESSION_TITLE => $self->session->param('title'),
		SESSION_AUTHOR => $self->session->param('author'),
		SESSION_DESCRIPTION => $self->session->param('description'),
		SESSION_LANGUAGE => $self->session->param('language'),
		SESSION_UNFOLD => $self->session->param('unfold'),
			'SESSION_UNFOLD_' . uc($self->session->param('unfold')) => 'yes',
		SESSION_CHAPTER => $self->session->param('chapter'),
			'SESSION_CHAPTER_' . uc($self->session->param('chapter')) => 'yes',
		SESSION_CHAPTER_FREE_TEXT => $self->session->param('chapter_free'),
		SESSION_CHAPTER_REGEX_TEXT => $self->session->param('chapter_regex'),
		SESSION_CHAPTER_EMPTYLINE => $self->session->param('chapter_emptyline'),
			'SESSION_CHAPTER_EMPTYLINE_' . uc($self->session->param('chapter_emptyline')) => 'yes',
		SESSION_LINK_URL => $self->session->param('link_url'),
			'SESSION_LINK_URL_' . uc($self->session->param('link_url')) => 'yes',
		SESSION_LINK_TWITTER => $self->session->param('link_twitter'),
			'SESSION_LINK_TWITTER_' . uc($self->session->param('link_twitter')) => 'yes',
		SESSION_LINK_PHONE => $self->session->param('link_phone'),
			'SESSION_LINK_PHONE_' . uc($self->session->param('link_phone')) => 'yes',
		SESSION_LINK_ZIPCODE => $self->session->param('link_zipcode'),
			'SESSION_LINK_ZIPCODE_' . uc($self->session->param('link_zipcode')) => 'yes',
		SESSION_LINEHEIGHT => $self->session->param('lineheight'),
			'SESSION_LINEHEIGHT_' . uc($self->session->param('lineheight')) => 'yes',
		SESSION_FONTSIZE => $self->session->param('fontsize'),
			'SESSION_FONTSIZE_' . uc($self->session->param('fontsize')) => 'yes',
		SESSION_FONTWEIGHT => $self->session->param('fontweight'),
			'SESSION_FONTWEIGHT_' . uc($self->session->param('fontweight')) => 'yes',
		SESSION_BACKGROUNDCOLOR => $self->session->param('backgroundcolor'),
			'SESSION_BACKGROUNDCOLOR_' . uc($self->session->param('backgroundcolor')) => 'yes',
		SESSION_COLOR => $self->session->param('color'),
			'SESSION_COLOR_' . uc($self->session->param('color')) => 'yes',
		EXPIRE_EPUB_HOUR => $self->config_param('system.expire_epub_hour'),
		EXPIRE_SESSION_MIN => $self->config_param('system.expire_session_min'),
		SESSION_RUBY => $self->session->param('ruby'),
			'SESSION_RUBY_' . uc($self->session->param('ruby')) => 'yes',
	);
	return $tmpl_obj->output();
}

sub mode_make {
	eval 'use Encode';
	eval 'use Encode::Guess qw(iso-2022-jp cp932 euc-jp)';
	eval 'use File::Basename';
	eval 'use Sort::Naturally'; # cpanm
	eval 'use I18N::LangTags::List'; # cpam?
	my $self = shift;
	$self = &set_query2session($self);
	$self->session->param('login' => 1);
	if ($self->query->param('mode') eq 'api') {
		if (!($ENV{'HTTPS'})) {
			return $self->forward('status', 'ERROR: APIモードはhttpでは実行不可にしています。<a href="' . &url_https($self) . '">httpsでアクセス</a>してください。', 'api');
		}
	}
	my($body_ref, $title_ref, $author_ref, $description_ref, $chapter_free_ref, $chapter_regex_ref, $body_original, %chapter_regex, $language_ref, $lineheight_ref, $fontsize_ref, $fontweight_ref, $backgroundcolor_ref, $color_ref);
	my($cover_filehandle_ref, $cover_info_ref);
	{
		my($title, $author, $body, $description, $chapter_free, $chapter_regex, $language, $lineheight, $fontsize, $fontweight, $backgroundcolor, $color);
		$title = $self->session->param('title');
		$author = $self->session->param('author');
		$body = $self->session->param('body');
		$description = $self->session->param('description');
		$chapter_free = $self->session->param('chapter_free');
		$chapter_regex = $self->session->param('chapter_regex');
		$language = $self->session->param('language');
		if (!(I18N::LangTags::List::name($language))) {
#			$language = $self->config_param('system.language');
			return $self->forward('status', 'ERROR: 想定外の言語が指定されています。[有効な言語 = ' . join(', ', sort(keys(%I18N::LangTags::List::Name))) . ']');
		}
		$lineheight = $self->session->param('lineheight');
		$fontsize = $self->session->param('fontsize');
		$fontweight = $self->session->param('fontweight');
		$backgroundcolor = $self->session->param('backgroundcolor');
		$color = $self->session->param('color');
		if ($self->query->param('bodyinput') eq 'file') {
			# body: file
			my @filehandle = $self->query->upload('textfile') or die('ERROR: アップロードするファイルが正しく選択されていません。');
			my @filepath = $self->query->param('textfile');
			my($i, %filename, $key, $buffer, $body_part, @filename_sort);
			my $decoder = Encode::Guess->guess(join('', @filepath));
			for ($i = 0; $i < scalar(@filepath); $i++) {
				my $basename = File::Basename::basename($filepath[$i]);
				if (ref($decoder)) {
					$basename = $decoder->decode($basename);
				}
				$filename{$basename} = $i;
			}
			$body = '';
			@filename_sort = Sort::Naturally::nsort(keys(%filename));
			foreach $key (@filename_sort) {
				$body_part = '';
				$i = $filename{$key};
				while (read($filehandle[$i], $buffer, 1024 * 1024)) {
					$body_part .= $buffer;
				}
				$decoder = Encode::Guess->guess($body_part);
				if (ref($decoder)) {
					$body_part = $decoder->decode($body_part);
				}
				$body_part = ${&normalize_cr(\$body_part)};
				if ($body eq '') {
					$body = $body_part;
				} elsif ($body =~ /\n$/) {
					$body .= $body_part;
				} else {
					$body .= "\n" . $body_part;
				}
			}
			if ($title eq '') {
				$title = join(', ', @filename_sort);
				$self->session->param('title' => $title);
			}
		} else {
			# body: input
			$body = ${&normalize_cr(\$body)};
		}
		$self->session->param('body' => $body);
		($chapter_free_ref, $chapter_regex_ref) = (\$chapter_free, \$chapter_regex);
		%chapter_regex = &set_chapter_regex($chapter_free_ref, $chapter_regex_ref);
		($body_original, $body_ref) = &set_body($self->session->param('unfold'), $body, \$chapter_regex{$self->session->param('chapter')}),
		$body = $self->query->escapeHTML($$body_ref);
		# cover
		if ($self->query->upload('coverfile')) {
			eval 'use Image::Info qw(image_info)';
			my @filehandle = $self->query->upload('coverfile');
			my($cover_filehandle) = $filehandle[0];
			$cover_info_ref = Image::Info::image_info($cover_filehandle);
			seek($cover_filehandle, 0, 0);
			my(%info) = %{$cover_info_ref};
			if (!($info{'file_media_type'})) {
				die('ERROR: アップロードする表紙画像が正しく選択されていません。');
			}
			$cover_filehandle_ref = \$cover_filehandle;
		}
		($body_ref, $title_ref, $author_ref, $description_ref, $language_ref, $lineheight_ref, $fontsize_ref, $fontweight_ref, $backgroundcolor_ref, $color_ref) = (\$body, \$title, \$author, \$description, \$language, \$lineheight, \$fontsize, \$fontweight, \$backgroundcolor, \$color);
	}
	$body_ref = &set_tagging($body_ref, $self->session->param('link_url'), $self->session->param('link_twitter'), $self->session->param('link_phone'), $self->session->param('link_zipcode'), $self->session->param('ruby'));
	my($chapter_ref, $navpoint_ref, $chapter_start) = &split_chapter($self, $body_ref, $title_ref, $chapter_regex{$self->session->param('chapter')}, $self->session->param('chapter_emptyline'));
	my $epub_dir = $self->param('epub_dir');
	&check_dir($epub_dir);
	my($file, $filesize) = &make_epub($self, $epub_dir, $title_ref, $author_ref, $description_ref, $chapter_ref, $navpoint_ref, $chapter_start, $language_ref, $lineheight_ref, $fontsize_ref, $fontweight_ref, $backgroundcolor_ref, $color_ref, \$body_original, $cover_filehandle_ref, $cover_info_ref);
	$self->session->param('file' => $file);
	my $flag_bodyinput_file;
	if ($self->session->param('bodyinput') eq 'file') {
		$flag_bodyinput_file = 1;
	}
	my $tmpl_obj;
	if ($self->query->param('mode') eq 'api') {
		$tmpl_obj = $self->load_tmpl('api_response.tmpl', case_sensitive => 1, default_escape => 'html');
		$tmpl_obj->param(
			MODE_API => 1,
			&set_tmpl($self),
			TITLE => 'API',
			#
			EPUB_FILENAME => &make_filename($$title_ref),
			EPUB_TITLE => $$title_ref,
			EPUB_FILESIZE => $filesize,
			URL_PREVIEW => &url_api($self, 'preview', { key => 'CGISESSID', value => $self->session->param('_SESSION_ID') }),
			URL_DOWNLOAD => &url_api($self, 'download', { key => 'CGISESSID', value => $self->session->param('_SESSION_ID') }),
			URL_EDIT => &url_api($self, 'edit', { key => 'CGISESSID', value => $self->session->param('_SESSION_ID') }),
		);
	} else {
		$tmpl_obj = $self->load_tmpl('make.tmpl', case_sensitive => 1, default_escape => 'html');
		$tmpl_obj->param(
			MODE_MAKE => 1,
			&set_tmpl($self),
			TITLE => 'EPUB Download',
			#
			EPUB_CHAPTER => $self->session->param('chapter'),
			EPUB_TOC_REF => $navpoint_ref,
			EPUB_FILESIZE => &commify_num($filesize),
			EPUB_LANGUAGE => $$language_ref,
			EPUB_LANGUAGE_HUMAN => I18N::LangTags::List::name($$language_ref),
			FLAG_BODYINPUT_FILE => $flag_bodyinput_file,
			URL_PRESET => &url_preset($self),
			MAILADDRESS => $self->session->param('mailaddress'),
			DOWNLOADKEY => $self->session->param('downloadkey'),
		);
	}
	return $tmpl_obj->output();
}

sub mode_download {
	eval 'use Path::Class'; # cpanm
	my $self = shift;
	my $dir = $self->param('epub_dir');
	my $file = $self->session->param('file');
	my $title = $self->session->param('title');
	my $epubfile = $dir . '/' . $file;
	if (($file) && (-e($epubfile))) {
		$self->header_type('none');
		printf('Content-Type: application/epub+zip' . "\n");
		printf('Content-Disposition: attachment; filename="%s"' . "\n", &make_filename($title));
		printf('Content-Length: %d' . "\n\n", -s($epubfile));
#		unlink($epubfile); # この問題 http://bit.ly/ryLQ10 を避けるためコメント化したっけな
		print scalar Path::Class::file($epubfile)->slurp( iomode => '<:raw' );
		return;
	} else {
		return $self->forward('status', 'ERROR: EPUBファイルが見つかりません。', 'api');
	}
}

sub mode_cleanup {
	eval 'use CGI::Session::ExpireSessions'; # cpanm
	my $self = shift;
	my $flag_delete = 'yes'; # yes or no
	my $life_epub    = $self->config_param('system.expire_epub_hour') * 60 * 60;
	my $life_session = $self->config_param('system.expire_session_min') * 60;
	my $epub_dir = $self->param('epub_dir');
	if ($self->query->param('password') ne $self->config_param('system.admin_password')) {
		return $self->forward('status', 'ERROR: 管理用パスワードが違います。');
	}
	# session
	my($session, $count_session_before, $count_session_after);
	$count_session_before = &count_sessionid($self);
	if ($flag_delete eq 'yes') {
		$session = CGI::Session::ExpireSessions->new(
			cgi_session_dsn => $self->config_param('database.cgi_session_dsn'),
			dsn_args => {
				DataSource => $self->config_param('database.dsn'),
				User => $self->config_param('database.user'),
				Password => $self->config_param('database.password'),
			},
			delta => $life_session
		)->expire_sessions();
	}
	$count_session_after = &count_sessionid($self);
	# epub
	my($count_epub_before, $count_epub_after, @file, $file);
	$count_epub_before = &count_file($epub_dir);
	if ($flag_delete eq 'yes') {
		opendir(DIR, $epub_dir);
		@file = grep { -f($epub_dir . '/' . $_) } readdir(DIR);
		closedir DIR;
		while (@file) {
			$file = $epub_dir . '/' . shift(@file);
			if ((time - (stat($file))[9]) > $life_epub) {
				unlink($file);
			}
		}
	}
	$count_epub_after = &count_file($epub_dir);
	# html
	my $tmpl_obj = $self->load_tmpl('cleanup.tmpl', case_sensitive => 1, default_escape => 'html');
	$tmpl_obj->param(
		MODE_CLEANUP => 1,
		&set_tmpl($self),
		TITLE => 'Cleanup',
		#
		FLAG_DELETE => $flag_delete,
		COUNT_SESSION_BEFORE => $count_session_before,
		COUNT_SESSION_AFTER => $count_session_after,
		COUNT_EPUB_BEFORE => $count_epub_before,
		COUNT_EPUB_AFTER => $count_epub_after,
		EXPIRE_EPUB_HOUR => $self->config_param('system.expire_epub_hour'),
		EXPIRE_SESSION_MIN => $self->config_param('system.expire_session_min'),
	);
	return $tmpl_obj->output();
}

sub mode_status {
	use bytes;
	my($self, $status, $mode) = @_;
	my($tmpl_obj, $contenttype);
	if ($mode eq 'api') {
		$tmpl_obj = $self->load_tmpl('api_response.tmpl', case_sensitive => 1, default_escape => 'html');
		$contenttype= 'text/xml';
	} else {
		$tmpl_obj = $self->load_tmpl('status.tmpl', case_sensitive => 1, default_escape => 'html');
		$contenttype= 'text/html';
	}
	$tmpl_obj->param(
		MODE_STATUS => 1,
		&set_tmpl($self),
		TITLE => 'Status',
		#
		DISABLE_SOCIALBAR => 1,
		DISABLE_AD => 1,
		DISABLE_SECURE => 1,
		STATUS => $status,
	);
#	$self->session_delete;
#	return $tmpl_obj->output();
	$self->header_type('none');
	printf('Content-Type: %s; charset=UTF-8' . "\n", $contenttype);
	printf('Content-Length: %d' . "\n\n", bytes::length($tmpl_obj->output()));
	print $tmpl_obj->output();
	return;
}

sub mode_preview {
	my($self, $status) = @_;
	my $flag_get;
	if (uc($ENV{'REQUEST_METHOD'}) eq 'GET') {
		$flag_get = 1;
	}
	my $tmpl_obj = $self->load_tmpl('republish.tmpl', case_sensitive => 1, default_escape => 'html');
	$tmpl_obj->param(
		MODE_PREVIEW => 1,
		&set_tmpl($self),
		TITLE => 'EPUB Preview',
		#
		FLAG_GET => $flag_get,
	);
	return $tmpl_obj->output();
}

sub mode_mail {
	eval 'use Encode';
	eval 'use Crypt::CBC'; # cpanm
	eval 'use Email::Valid::Loose'; # cpanm
	eval 'use Email::Sender::Simple qw(sendmail)'; # cpanm
	eval 'use Email::Simple'; # cpanm
	eval 'use Email::Simple::Creator'; # cpanm
	eval 'use MIME::Base64::URLSafe'; # cpanm
	my $self = shift;
	unless ($self->session->param('login')) {
		return $self->json_body( { message => 'ERROR: セッション情報がありません。', } );
	};
	my $mailaddress = Encode::decode_utf8( $self->query->param('mailaddress') );
	my $downloadkey = Encode::decode_utf8( $self->query->param('downloadkey') );
	unless (length($downloadkey) > 0) {
		return $self->json_body( { message => 'ERROR: アイコトバは1文字以上入力してください。', } );
	};
	unless (Email::Valid::Loose->address( -address => $mailaddress, -mxcheck => 1 )) {
		return $self->json_body( { message => 'ERROR: メールアドレスの形式がどこか正しくないようです。', } );
	};
	$self->session->param('mailaddress' => $mailaddress);
	$self->session->param('downloadkey' => $downloadkey);
	my $cbc = Crypt::CBC->new( -key => $downloadkey, -cipher => 'Blowfish_PP', -padding => 'null' );
	my $tmpl_obj = $self->load_tmpl('mail.tmpl', case_sensitive => 1, default_escape => 'none');
	$tmpl_obj->param(
		MODE_MAIL => 1,
		&set_tmpl($self),
		TITLE => '',
		#
		MAILADDRESS => $mailaddress,
		EXPIRE_EPUB_HOUR => $self->config_param('system.expire_epub_hour'),
		EXPIRE_SESSION_MIN => $self->config_param('system.expire_session_min'),
		URL_DOWNLOAD => &url_api($self, 'click', { key => 'id', value => MIME::Base64::URLSafe::encode($cbc->encrypt(pack('H*', $self->session->param('_SESSION_ID')))) }),
		URL_DOWNLOAD_HTTP => &url_api($self, 'click', { key => 'id', value => MIME::Base64::URLSafe::encode($cbc->encrypt(pack('H*', $self->session->param('_SESSION_ID')))) }, 'http'),
	);
	my $email = Email::Simple->create(
		header => [
			'Content-Transfer-Encoding' => '7bit',
			'Content-Type' => 'text/plain; charset=iso-2022-jp',
			From    => Encode::encode('MIME-Header-ISO_2022_JP' => $self->config_param('system.email_from')),
			To      => Encode::encode('MIME-Header-ISO_2022_JP' => $mailaddress),
			Subject => Encode::encode('MIME-Header-ISO_2022_JP' => $self->config_param('system.email_subject')),
		],
		body => Encode::encode('iso-2022-jp', Encode::decode_utf8($tmpl_obj->output())),
	);
	&sendmail($email, { from => $self->config_param('system.email_envelopefrom') } );
	return $self->json_body( { message => sprintf('ダウンロードURLを「From: %s」「To: %s」でメール送信しました。着信を確認してみてください。', $self->config_param('system.email_from'), $mailaddress), } );
}

sub mode_click {
	eval 'use Encode';
	eval 'use Crypt::CBC'; # cpanm
	eval 'use MIME::Base64::URLSafe'; # cpanm
	eval 'use URL::Escape'; # cpanm
	my $self = shift;
	my $downloadkey = Encode::decode_utf8( $self->query->param('downloadkey') );
	if (uc($ENV{'REQUEST_METHOD'}) eq 'GET') {
		my $tmpl_obj = $self->load_tmpl('click.tmpl', case_sensitive => 1, default_escape => 'html');
		$tmpl_obj->param(
			MODE_CLICK => 1,
			&set_tmpl($self),
			TITLE => 'EPUB Download URL',
			#
			ID => $self->query->param('id'),
			DISABLE_SOCIALBAR => 1,
			DISABLE_SECURE => 1,
		);
		return $tmpl_obj->output();
	} else {
		my $cbc = Crypt::CBC->new( -key => $downloadkey, -cipher => 'Blowfish_PP', -padding => 'null' );
		my $id = lc(join('', unpack('H*', $cbc->decrypt(MIME::Base64::URLSafe::decode($self->query->param('id'))))));
		if (!($id =~ /^[0-9a-f]{32}$/)) {
			return $self->forward('status', 'ERROR: アイコトバが合っていないみたいです。');
		}
		my $url_download;
		if ($ENV{'HTTPS'}) {
			$url_download = &url_api($self, 'download', { key => 'CGISESSID', value => $id } );
		} else {
			$url_download = &url_api($self, 'download', { key => 'CGISESSID', value => $id }, 'http');
		}
		return $self->redirect($url_download);
	}
}

sub mode_ad {
	eval 'use Net::Amazon'; # cpanm
	eval 'use Cache::File'; # cpanm
	eval 'use LWP';
	my $self = shift;
	if ($self->query->param('password') ne $self->config_param('system.admin_password')) {
		return $self->forward('status', 'ERROR: 管理用パスワードが違います。');
	}
	if ($ENV{'HTTPS'}) {
		# 作者の設置サーバでは、httpアクセスとhttpsアクセスでApacheの実行権限が異なり、統一しておかないとファイルの扱いが厄介になるため。
		return $self->forward('status', 'ERROR: ADモードはhttpsアクセスでは実行不可です。httpアクセスでお願いします。');
	}
	my($i, $html, @amazon, $amazon_ref, @url, @count);
	for ($i = 1; $i < 10; $i++) {
		if (defined($self->config_param('amazon.url_' . $i))) {
			push(@url, $self->config_param('amazon.url_' . $i));
			push(@count, $self->config_param('amazon.count_' . $i));
		}
	}
	my $id_regex = $self->config_param('amazon.id_regex');
	for ($i = 0; $i < scalar(@url); $i++) {
		$html = LWP::UserAgent->new->get($url[$i])->content;
		my(@tmp, %tmp);
		while ($html =~ /$id_regex/gmo) {
			push(@tmp, $1);
		}
		@tmp = grep(!$tmp{$_}++, @tmp);
		splice(@tmp, $count[$i]);
		$amazon_ref = &search_amazon($self, \@tmp, 'salesrank', $self->config_param('amazon.imagesize')); # salesrank, daterank, ''
		push(@amazon, @$amazon_ref);
	}
	my($width_max);
	($amazon_ref, $width_max) = &width_amazon(\@amazon);
	# html (http)
	my $tmpl_obj = $self->load_tmpl('ad.tmpl', case_sensitive => 1, default_escape => 'html', global_vars => 1);
	my $file_output = 'ad_output_http.tmpl';
	$tmpl_obj->param(
		MODE_AD => 1,
		&set_tmpl($self),
		TITLE => 'Ad',
		#
		AMAZON_REF => $amazon_ref,
		WIDTH_MAX => $width_max + (3 * 2), # .book_item img border
	);
	open(FILE, '>' . $self->param('template_dir') . '/' . $file_output);
	$tmpl_obj->output(print_to => *FILE);
	close(FILE);
	# html (https)
	$file_output = 'ad_output_https.tmpl';
	$tmpl_obj->param(
		HTTPS => 'yes',
	);
	open(FILE, '>' . $self->param('template_dir') . '/' . $file_output);
	$tmpl_obj->output(print_to => *FILE);
	close(FILE);
	return $self->forward('status', 'OK: ADファイルの生成を行いました。');
}

sub set_default {
	my %default = (
		'language' => 'ja',
		'title' => 'TEST',
		'author' => '',
		'description' => '',
		'bodyinput' => 'text',
		'body' => '',
		'chapter' => 'free',
		'chapter_free' => '■,□,●,○,★,☆',
		'chapter_regex' => '',
		'chapter_emptyline' => 1,
		'unfold' => 0,
		'lineheight' => 160,
		'fontsize' => '',
		'fontweight' => '',
		'backgroundcolor' => '',
		'color' => '',
		'link_url' => '1',
		'link_twitter' => '1',
		'link_phone' => '0',
		'link_zipcode' => '0',
		'ruby' => '0',
	);
	return(\%default);
}

sub set_tmpl {
	my $self = shift;
	my %default = (
		VERSION => $self->config_param('system.version'),
		SITENAME => $self->config_param('system.sitename'),
		SITENAME_SHORT => $self->config_param('system.sitename_short'),
		URL => $self->config_param('system.url'),
		TWITTER_URL => $self->config_param('system.twitter_url'),
		TWITTER_ACCOUNT => $self->config_param('system.twitter_account'),
		GUMROAD_URL => $self->config_param('system.gumroad_url'),
		GUMROAD_TEXT => $self->config_param('system.gumroad_text'),
		ADMIN_NAME => $self->config_param('system.admin_name'),
		ADMIN_MAILADDRESS => $self->config_param('system.admin_mailaddress'),
		HTTPS => $ENV{'HTTPS'},
		URL_HTTPS => &url_https($self),
		URL_NOW => &url_now(),
	);
	return(%default);
}

sub set_query2session {
	my($self) = @_;
	my $decoder = Encode::Guess->guess($self->query->param('dummy') . $self->query->param('title') . $self->query->param('author') . $self->query->param('body') . $self->query->param('description'));
	my($default_ref, $key);
	$default_ref = &set_default();
	foreach $key (keys(%{$default_ref})) {
		if (defined($self->query->param($key))) {
			unless (ref($decoder)) {
				$self->session->param($key => $self->query->param($key));
			} else {
				$self->session->param($key => $decoder->decode($self->query->param($key)));
			}
		} else {
			unless (defined($self->session->param($key))) {
				$self->session->param($key => $$default_ref{$key});
			}
		}
		if ($key ne 'body') {
			$self->session->param($key => ${&cut_cr(\$self->session->param($key))});
		}
	}
	return($self);
}

sub url_preset {
	eval 'use URI::Escape'; # cpanm
	my $self = shift;
	my($default_ref, $key);
	my(@query) = 'mode=edit';
	$default_ref = &set_default();
	foreach $key (sort(keys(%{$default_ref}))) {
		if (($key ne 'body') && ($key ne 'bodyinput')) {
			if ($$default_ref{$key} ne $self->session->param($key)) {
				push(@query, sprintf('%s=%s', $key, URI::Escape::uri_escape_utf8($self->session->param($key))));
			}
		}
	}
	return(&url_now() . '?' . join('&', @query));
}

sub url_now {
	my $url;
	if (!($ENV{'HTTPS'})) {
		$url = 'http://' . &url_full();
	} else {
		$url = 'https://' . &url_full();
	}
	return($url);
}

sub url_https {
	my $self = shift;
	my $url;
	if (!($ENV{'HTTPS'})) {
		$url = 'https://' . $self->config_param('system.https_server') . '/' . &url_full();
	} else {
		$url = 'https://' . &url_full();
	}
	return($url);
}

sub url_http {
	my $self = shift;
	my $url;
	if ($ENV{'HTTPS'}) {
		my $cut = quotemeta($self->config_param('system.https_server') . '/');
		$url = 'http://' . &url_full();
		$url =~ s/$cut//;
	} else {
		$url = 'http://' . &url_full();
	}
	return($url);
}

sub url_full {
	return(lc($ENV{'HTTP_HOST'}) . substr($ENV{'SCRIPT_NAME'}, 0, rindex($ENV{'SCRIPT_NAME'}, '/')) . '/');
}

sub url_api {
	eval 'use URI::Escape'; # cpanm
	my($self, $mode, $hash_ref, $protocol) = @_;
	if ($protocol eq 'http') {
		return(sprintf('%s?%s=%s&mode=%s', &url_http($self), $$hash_ref{'key'}, URI::Escape::uri_escape_utf8($$hash_ref{'value'}), $mode));
	} else {
		return(sprintf('%s?%s=%s&mode=%s', &url_https($self), $$hash_ref{'key'}, URI::Escape::uri_escape_utf8($$hash_ref{'value'}), $mode));
	}
}

sub commify_num { # thanks: http://www.din.or.jp/~ohzaki/perl.htm#NumberWithComma
	my($num) = @_;
	my($i, $j);
	if ($num =~ /^[-+]?\d\d\d\d+/g) {
		for ($i = pos($num) - 3, $j = $num =~ /^[-+]/; $i > $j; $i -= 3) {
			substr($num, $i, 0) = ',';
		}
	}
	return($num);
}

sub cut_cr {
	my($text_ref) = @_;
	$text_ref = &normalize_cr($text_ref);
	$$text_ref =~ s/\n//g;
	return($text_ref);
}

sub normalize_cr {
	my($text_ref) = @_;
	$$text_ref =~ s/\x0D\x0A/\n/g;
	$$text_ref =~ tr/\x0D\x0A/\n\n/;
	return($text_ref);
}

sub set_tagging {
	my($body_ref, $flag_url, $flag_twitter, $flag_phone, $flag_zipcode, $flag_ruby) = @_;
	if ($flag_ruby) {
		$body_ref = &tagging_ruby($body_ref, $flag_ruby);
	}
	if ($flag_phone) {
		$body_ref = &tagging_phone($body_ref);
	}
	if ($flag_zipcode) {
		$body_ref = &tagging_zipcode($body_ref);
	}
	if ($flag_twitter) {
		$body_ref = &tagging_twitter($body_ref);
	}
	if ($flag_url) {
		$body_ref = &tagging_url($body_ref);
	}
	return($body_ref);
}

sub set_body {
	my($unfold, $body, $chapter_regex_ref) = @_;
	my($body_original, $body_ref);
	if ($unfold > 0) {
		$body_original = $body;
		$body_ref = &unfold_text([ split("\n", $body) ], $chapter_regex_ref, $unfold);
	} else {
		$body_original = $body;
		$body_ref = \$body;
	}
	return($body_original, $body_ref);
}

sub set_chapter_regex {
	my($free_ref, $regex_ref) = @_;
	my %tmp = map { quotemeta($_) => 'yes' } split(/,/, $$free_ref);
	my $tmp = join('|', keys(%tmp));
	my %regex = (
		'no' => undef,
		'free' => '^(' . $tmp . ')',
		'symbol' => '^(■|□|●|○|★|☆)',
		'dp' => '^(\d{1,2}\.)',
		'zd' => '^(１|２|３|４|５|６|７|８|９|０)',
		'rn' => '^(Ⅰ|Ⅱ|Ⅲ|Ⅳ|Ⅴ|Ⅵ|Ⅶ|Ⅷ|Ⅸ|Ⅹ)',
		'cd' => '^(①|②|③|④|⑤|⑥|⑦|⑧|⑨|⑩|⑪|⑫|⑬|⑭|⑮|⑯|⑰|⑱|⑲|⑳)',
		'wz' => '^(\.{1,6})[^\.]',
		'wiki' => '^(\={1,6} )',
		'regex' => $$regex_ref,
		# preset
		'preset_sciencemail' => '^(\[\d{1,2}:|\[編集後記\])', # ScienceMail http://moriyama.com/sciencemail/
	);
	return(%regex);
}

sub width_amazon {
	my($amazon_ref) = @_;
	my($i, @return, $width_max, $width);
	$width_max = 0;
	for ($i = 0; $i < scalar(@$amazon_ref); $i++) {
		$width = $$amazon_ref[$i]{'WIDTH'};
		push(@return, $$amazon_ref[$i]);
		if ($width > $width_max) {
			$width_max = $width;
		}
	}
	return(\@return, $width_max);
}

sub search_amazon {
	my($self, $asin_ref, $sort, $imagesize) = @_;
	my $cache_dir = $self->param('amazon_dir');
	&check_dir($cache_dir);
	my $cache = Cache::File->new(
			cache_root => $cache_dir,
			lock_level => Cache::File::LOCK_LOCAL(),
			default_expires => '24 hours',
		);
	my $aws = Net::Amazon->new(
			cache => $cache,
			associate_tag => $self->config_param('amazon.associate_tag'),
			token => $self->config_param('amazon.token'),
			secret_key => $self->config_param('amazon.secret_key'),
			locale => $self->config_param('amazon.locale'),
		);
	my @return;
	my $response = $aws->search(asin => $asin_ref, sort => $sort);
	if($response->is_success()) {
		for ($response->properties()) { # thanks: http://search.cpan.org/~boumenot/Net-Amazon/lib/Net/Amazon/Property.pm
			push(@return, 
				{
					'ASIN' => $_->ASIN() . '',
					'URL' => $_->url() . '',
					'NAME' => $_->ProductName() . '',
					'DESCRIPTION' => $_->ProductDescription() . '',
					'PRICE' => $_->OurPrice(),
					'IMAGE_LARGE' => $_->ImageUrlLarge() . '',
					'WIDTH_LARGE' => $_->LargeImageWidth(),
					'HEIGHT_LARGE' => $_->LargeImageHeight(),
					'IMAGE_MEDIUM' => $_->ImageUrlMedium() . '',
					'WIDTH_MEDIUM' => $_->MediumImageWidth(),
					'HEIGHT_MEDIUM' => $_->MediumImageHeight(),
					'IMAGE_SMALL' => $_->ImageUrlSmall() . '',
					'WIDTH_SMALL' => $_->SmallImageWidth(),
					'HEIGHT_SMALL' => $_->SmallImageHeight(),
#					'MEDIA' => $_->Media() . '',
#					'AUTHOR' => $_->authors(),
				});
#				if (ref($return[$#return]{'AUTHOR'}) eq 'ARRAY') {
#					$return[$#return]{'AUTHOR'} = join('/', @{$return[$#return]{'AUTHOR'}});
#				}
			if ($imagesize eq 'large') {
				$return[$#return]{'IMAGE_HTTP'} = $return[$#return]{'IMAGE_LARGE'};
				$return[$#return]{'WIDTH'} = $return[$#return]{'WIDTH_LARGE'};
				$return[$#return]{'HEIGHT'} = $return[$#return]{'HEIGHT_LARGE'};
			} elsif ($imagesize eq 'small') {
				$return[$#return]{'IMAGE_HTTP'} = $return[$#return]{'IMAGE_SMALL'};
				$return[$#return]{'WIDTH'} = $return[$#return]{'WIDTH_SMALL'};
				$return[$#return]{'HEIGHT'} = $return[$#return]{'HEIGHT_SMALL'};
			} else {
				$return[$#return]{'IMAGE_HTTP'} = $return[$#return]{'IMAGE_MEDIUM'};
				$return[$#return]{'WIDTH'} = $return[$#return]{'WIDTH_MEDIUM'};
				$return[$#return]{'HEIGHT'} = $return[$#return]{'HEIGHT_MEDIUM'};
			}
			if ($return[$#return]{'IMAGE_HTTP'} eq '') {
				$return[$#return]{'IMAGE_HTTP'} = 'http://ec1.images-amazon.com/images/G/09/en_JP/nav2/dp/no-image-avail-tny.gif';
				$return[$#return]{'WIDTH'} = 65;
				$return[$#return]{'HEIGHT'} = 65;
			}
			$return[$#return]{'IMAGE_HTTPS'} = $return[$#return]{'IMAGE_HTTP'};
			$return[$#return]{'IMAGE_HTTPS'} =~ s|^(https?://[^/]+)/||;
			$return[$#return]{'IMAGE_HTTPS'} = 'https://images-na.ssl-images-amazon.com/' . $return[$#return]{'IMAGE_HTTPS'};
			if ($return[$#return]{'PRICE'} =~ /^￥/) {
				$return[$#return]{'PRICE'} =~ s/^￥\s/￥/g;
			}
		}
	} else {
		@return = ();
	}
	return(\@return);
}

sub count_file {
	my($dir) = @_;
	opendir(DIR, $dir);
	my @files = grep { -f($dir . '/' . $_) } readdir(DIR);
	closedir DIR;
	return(scalar(@files));
}

sub count_sessionid {
	my $self = shift;
	my $sth = $self->dbh->prepare('SELECT COUNT(*) FROM sessions;') || die($DBI::errstr);
	$sth->execute() || die($DBI::errstr);
	my $count = @{$sth->fetchrow_arrayref()}[0];
	return($count);
}

sub make_filename {
	eval 'use Lingua::JA::Romanize::Japanese'; # cpanm
	my($title) = @_;
	my @datetime = localtime();
	my($filename);
	if (defined($title) && ($title ne '')) {
		my $romanize = Lingua::JA::Romanize::Japanese->new();
		my($yomi, @yomi_1, @yomi_2);
		@yomi_1 = split(' ', $romanize->chars($title));
		while (@yomi_1) {
			@yomi_2 = split('/', shift(@yomi_1));
			$yomi .= $yomi_2[0];
		}
		$yomi = ${&normalize_text($yomi)};
		$yomi =~ s/\s//g;
		$yomi =~ s/[^0-9a-zA-Z_\-\(\)]//g;
		$filename = sprintf('%s.epub', substr($yomi, 0, 44));
	} else {
		$filename = sprintf('genepub-%04d%02d%02d%02d%02d%02d.epub', $datetime[5] + 1900, $datetime[4] + 1, $datetime[3], $datetime[2], $datetime[1], $datetime[0]);
	}
	return($filename);
}

sub split_chapter {
	my($self, $text_ref, $title_ref, $heading_regex, $flag_emptyline) = @_;
	my @text = split("\n", $$text_ref);
	my($id, @chapter, @navpoint, $i);
	my($chapter_no) = 0;
	my($chapter_line) = 0;
	$chapter[$chapter_no][0] = '';
	$navpoint[$chapter_no]{'CONTENT'} = sprintf('chapter_%d.xhtml', $chapter_no);
	$navpoint[$chapter_no]{'LABEL'} = $self->query->escapeHTML($$title_ref);
	my $flag_condition;
	for ($i = 0; $i < scalar(@text); $i++) {
		$flag_condition = 0;
		if ($flag_emptyline > 0) {
			if ($i == 0) {
				if ($text[$i+1] =~ /^(\s|　)*$/) {
					$flag_condition = 1;
				}
			} else {
				if (($flag_emptyline == 1) && (($text[$i-1] =~ /^(\s|　)*$/) || ($text[$i+1] =~ /^(\s|　)*$/))) {
					$flag_condition = 1;
				} elsif (($flag_emptyline == 2) && ($text[$i-1] =~ /^(\s|　)*$/) && ($text[$i+1] =~ /^(\s|　)*$/)) {
					$flag_condition = 1;
				}
			}
		}
		if (
				($heading_regex) && ($text[$i] =~ /$heading_regex/) &&
				(
					($flag_emptyline == 0) || 
					($flag_emptyline > 0) && ($flag_condition == 1)
				)
			) {
			$id = sprintf('genepub-line%d', $i + 1);
			$chapter_no ++;
			$chapter_line = 0;
			$chapter[$chapter_no][$chapter_line] = sprintf('<h1 id="%s"><a href="%s">%s</a></h1>', $id, 'toc.xhtml', $text[$i]);
			$navpoint[$chapter_no]{'CONTENT'} = sprintf('chapter_%d.xhtml', $chapter_no);
			$navpoint[$chapter_no]{'LABEL'} = $text[$i];
		} else {
			$chapter[$chapter_no][$chapter_line] = $text[$i];
		}
		$chapter_line ++;
	}
	my $chapter_start = 0;
	if ($heading_regex) {
		$chapter_start = 1;
		for ($i = 0; $i < scalar(@{$chapter[0]}); $i++) {
			if ($chapter[0][$i] =~ /\S/) {
				$chapter_start = 0;
				last;
			}
		}
	}
	return(\@chapter, \@navpoint, $chapter_start);
}

sub make_epub {
	eval 'use EBook::EPUB'; # cpanm
	eval 'use File::Copy';
	eval 'use File::Temp qw(tempdir)';
	eval 'use Path::Class'; # cpanm
	my($self, $epub_dir, $title_ref, $author_ref, $description_ref, $chapter_ref, $navpoint_ref, $chapter_start, $language_ref, $lineheight_ref, $fontsize_ref, $fontweight_ref, $backgroundcolor_ref, $color_ref, $body_original_ref, $cover_filehandle_ref, $cover_info_ref) = @_;
	my $tmp_dir_obj = File::Temp->newdir(CLEANUP => 1);
	my $tmp_dir = $tmp_dir_obj->dirname;
	my $file_epub = 'genepub-' . $self->session->param('_SESSION_ID') . '.epub';
	my $file_plain = 'original.txt';
	my @datetime = localtime();
	my $epub = EBook::EPUB->new;
	$epub->add_title($self->query->escapeHTML($$title_ref));
	$epub->add_language($self->query->escapeHTML($$language_ref));
	$epub->add_identifier(sprintf('%s/?%04d%02d%02d%02d%02d%02d', $self->config_param('system.url'), $datetime[5] + 1900, $datetime[4] + 1, $datetime[3], $datetime[2], $datetime[1], $datetime[0]), 'URL');
	$epub->add_date(sprintf('%04d-%02d-%02d', $datetime[5] + 1900, $datetime[4] + 1, $datetime[3]));
	$epub->add_description($self->query->escapeHTML($$description_ref));
	$epub->add_author($self->query->escapeHTML($$author_ref));
	# css
	my $tmpl_obj = $self->load_tmpl('epub_yoko.css', case_sensitive => 1, default_escape => 'html');
	$tmpl_obj->param(
		LINEHEIGHT => $$lineheight_ref,
		FONTSIZE => $$fontsize_ref,
		FONTWEIGHT => $$fontweight_ref,
		BACKGROUNDCOLOR => $$backgroundcolor_ref,
		COLOR => $$color_ref,
	);
	$epub->add_stylesheet('main.css', Encode::decode_utf8( $tmpl_obj->output()) );
	my($chapter_id, $navpoint, $i);
	my($playorder) = 1;
	my(%subpage) = (
		'cover' => { content => 'cover.xhtml', label => $self->query->escapeHTML(Encode::decode_utf8($self->config_param('system.label_cover'))) },
		'toc' => { content => 'toc.xhtml', label => $self->query->escapeHTML(Encode::decode_utf8($self->config_param('system.label_toc'))) },
		'information' => { content => 'genepub.xhtml', label => $self->query->escapeHTML(Encode::decode_utf8($self->config_param('system.label_information'))) },
		'original' => { content => $file_plain, label => $self->query->escapeHTML(Encode::decode_utf8($self->config_param('system.label_original'))) },
	);
	$tmpl_obj = $self->load_tmpl('epub_chapter.tmpl', case_sensitive => 1, default_escape => 'none');
	if (defined($$cover_filehandle_ref)) {
		# cover
		my($file_cover) = 'cover.' . lc($$cover_info_ref{'file_ext'});
		my($cover_id);
		if (($$cover_info_ref{'Orientation'} ne '') && ($$cover_info_ref{'Orientation'} ne 'top_left')) {
			eval 'use Image::Magick';
			my($tmp_cover) = Path::Class::file($tmp_dir, $file_cover);
			my($im) = Image::Magick->new();
			$im->Read(file => $$cover_filehandle_ref);
			$im->Set(quality => $self->config_param('system.cover_quality'));
			$im->Rotate(degrees =>  90 ) if ( $$cover_info_ref{'Orientation'} eq 'right_top');
			$im->Rotate(degrees => 180 ) if ( $$cover_info_ref{'Orientation'} eq 'bot_right');
			$im->Rotate(degrees => 270 ) if ( $$cover_info_ref{'Orientation'} eq 'left_bot');
			$im->Write(filename => $tmp_cover);
			$cover_id = $epub->copy_image($tmp_cover, $file_cover, $$cover_info_ref{'file_media_type'});
		} else {
			my($buffer);
			read($$cover_filehandle_ref, $buffer, -s($$cover_filehandle_ref));
			$cover_id = $epub->add_image($file_cover, $buffer, $$cover_info_ref{'file_media_type'});
		}
		$epub->add_meta_item('cover', $cover_id);
		my($cover_size_long);
		if (($$cover_info_ref{'Orientation'} eq 'right_top') || ($$cover_info_ref{'Orientation'} eq 'left_bot')) {
			if ($$cover_info_ref{'width'} > $$cover_info_ref{'height'}) {
				$cover_size_long = 'height';
			} else {
				$cover_size_long = 'width';
			}
		} else {
			if ($$cover_info_ref{'width'} > $$cover_info_ref{'height'}) {
				$cover_size_long = 'width';
			} else {
				$cover_size_long = 'height';
			}
		}
		$tmpl_obj->param(
			TITLE => $subpage{'cover'}{'label'},
			LANGUAGE => $self->config_param('system.language'),
			BODY => sprintf('<img src="%s" class="genepub-cover" alt="%s" %s="100%%" />', $file_cover, $subpage{'cover'}{'label'}, $cover_size_long),
		);
		$chapter_id = $epub->add_xhtml($subpage{'cover'}{'content'}, Encode::decode_utf8( $tmpl_obj->output() ));
		$navpoint = $epub->add_navpoint(
			label => $subpage{'cover'}{'label'},
			id => $chapter_id,
			content => $subpage{'cover'}{'content'},
			play_order => $playorder,
		);
		$playorder ++;
	}
	{
		# toc
		my $tmpl_obj_child = $self->load_tmpl('epub_toc.tmpl', case_sensitive => 1, default_escape => 'none');
		my $body;
		for ($i = $chapter_start; $i < scalar(@$navpoint_ref); $i++) {
			$body .= sprintf('<li><a href="%s">%s</a></li>', $$navpoint_ref[$i]{'CONTENT'}, $$navpoint_ref[$i]{'LABEL'});
		}
		$body .= sprintf('<li><a href="%s">%s</a></li>', $subpage{'information'}{'content'}, $subpage{'information'}{'label'});
#		$body .= sprintf('<li><a href="%s">%s</a></li>', $subpage{'original'}{'content'}, $subpage{'original'}{'label'});
		$tmpl_obj_child->param(
			TITLE => ${&set_tagging(\$self->query->escapeHTML($$title_ref), $self->session->param('link_url'), $self->session->param('link_twitter'), $self->session->param('link_phone'), $self->session->param('link_zipcode'), $self->session->param('ruby'))},
			AUTHOR => ${&set_tagging(\$self->query->escapeHTML($$author_ref), $self->session->param('link_url'), $self->session->param('link_twitter'), $self->session->param('link_phone'), $self->session->param('link_zipcode'), $self->session->param('ruby'))},
			DESCRIPTION => ${&set_tagging(\$self->query->escapeHTML($$description_ref), $self->session->param('link_url'), $self->session->param('link_twitter'), $self->session->param('link_phone'), $self->session->param('link_zipcode'), $self->session->param('ruby'))},
			TOC_TITLE => $subpage{'toc'}{'label'},
			TOC_BODY => $body,
		);
		$tmpl_obj->param(
			TITLE => $self->query->escapeHTML($$title_ref),
			LANGUAGE => $self->query->escapeHTML($$language_ref),
			BODY => $tmpl_obj_child->output(),
		);
		$chapter_id = $epub->add_xhtml($subpage{'toc'}{'content'}, Encode::decode_utf8( $tmpl_obj->output() ));
		$navpoint = $epub->add_navpoint(
			label => $subpage{'toc'}{'label'},
			id => $chapter_id,
			content => $subpage{'toc'}{'content'},
			play_order => $playorder,
		);
		$playorder ++;
	}
	# contents
	for ($i = $chapter_start; $i < scalar(@$navpoint_ref); $i++) {
		$tmpl_obj->param(
			TITLE => $$navpoint_ref[$i]{'LABEL'},
			LANGUAGE => $self->query->escapeHTML($$language_ref),
			BODY => join('<br />' . "\n", @{$$chapter_ref[$i]}),
		);
		$chapter_id = $epub->add_xhtml(sprintf('chapter_%s.xhtml', $i), Encode::decode_utf8( $tmpl_obj->output() ));
		$navpoint = $epub->add_navpoint(
			label => $$navpoint_ref[$i]{'LABEL'},
			id => $chapter_id,
			content => $$navpoint_ref[$i]{'CONTENT'},
			play_order => $playorder,
		);
		$playorder ++;
	}
	{
		# information
		my $tmpl_obj_child = $self->load_tmpl('epub_genepub.tmpl', case_sensitive => 1, default_escape => 'none');
		$tmpl_obj_child->param(
			&set_tmpl($self),
			TITLE => sprintf('<a href="%s">', $subpage{'toc'}{'content'}) . $subpage{'information'}{'label'} . '</a>',
			DATE => sprintf('%d年%d月%d日', $datetime[5] + 1900, $datetime[4] + 1, $datetime[3]),
		);
		$tmpl_obj->param(
			TITLE => $subpage{'information'}{'label'},
			LANGUAGE => $self->config_param('system.language'),
			BODY => $tmpl_obj_child->output(),
		);
		$chapter_id = $epub->add_xhtml($subpage{'information'}{'content'}, Encode::decode_utf8( $tmpl_obj->output() ));
		$navpoint = $epub->add_navpoint(
			label => $subpage{'information'}{'label'},
			id => $chapter_id,
			content => $subpage{'information'}{'content'},
			play_order => $playorder,
		);
		$playorder ++;
	}
	{
		# original text
		open(FILE, '>' . Path::Class::file($tmp_dir, $file_plain));
		print FILE $$body_original_ref;
		close(FILE);
		$chapter_id = $epub->copy_file(Path::Class::file($tmp_dir, $file_plain), $file_plain, 'text/plain');
#		$navpoint = $epub->add_navpoint(
#			label => $subpage{'original'}{'label'},
#			id => $chapter_id,
#			content => $subpage{'original'}{'content'},
#			play_order => $playorder,
#		);
#		$playorder ++;
	}
	my $tmp_epub = Path::Class::file($tmp_dir, $file_epub);
	$epub->pack_zip("$tmp_epub");
	File::Copy::move($tmp_epub, $epub_dir);
	chmod(0666, Path::Class::file($epub_dir, $file_epub));
	return($file_epub, -s(Path::Class::file($epub_dir, $file_epub)));
}

sub normalize_text {
	my($text) = @_;
	$text =~ s/\n *//g;
	$text =~ s/\n//g;
	$text =~ s/　//g;
	$text =~ s/\t/ /g;
	$text =~ tr/０-９ａ-ｚＡ-Ｚ〜！＠＃＄％＾＆＊＋＝：；／/0-9a-zA-Z~!@#$%^&*+=:;\//;
	return(\lc($text));
}

sub check_dir {
	my $dir = shift;
	die(sprintf('%s: %s', $!, $dir)) unless (-d $dir);
	die(sprintf('%s: %s', $!, $dir)) unless (-w $dir);
	return;
}

sub unfold_text {
	eval 'use Text::Ngrams'; # cpanm
	my($text_ref, $regex_ref, $margin) = @_;
	my($width_ref, $maxwidth) = &check_width($text_ref, $regex_ref);
	my($i, $result);
	for ($i = 0; $i < scalar(@$width_ref); $i++) {
		if ($$width_ref[$i][0] == 0) {
			$result .= $$text_ref[$i] . "\n";
		} elsif (
					(&check_pattern(\$$text_ref[$i]) == 0) && 
					($$width_ref[$i+1][0] == 1) && 
					(($$width_ref[$i][1] >= ($maxwidth - $margin)) && ($$width_ref[$i][1] <= ($maxwidth + $margin)))
				) {
			$result .= $$text_ref[$i];
		} else {
			$result .= $$text_ref[$i] . "\n";
		}
	}
	return(\$result);
}

sub delete_epub {
	my($self, $file) = @_;
	my $flag_delete = 'yes'; # yes or no
	my $epub_dir = $self->param('epub_dir');
	if ($flag_delete eq 'yes') {
		unlink($epub_dir . '/' . $file);
	}
	return;
}

sub check_pattern {
	my($text_ref) = @_;
	my($border) = 0.65;
	my($ng, $pattern, $freq, $i);
	my($length) = length($$text_ref);
	my($flag_pattern) = 0;
	for ($i = 2; $i < ($length / 2); $i++) {
		$ng = Text::Ngrams->new( type => 'byte', windowsize => $i );
		$ng->process_text($$text_ref);
		($pattern, $freq) = $ng->get_ngrams( orderby => 'frequency', onlyfirst => 1 );
		if ((($i * $freq) / $length) > $border) {
			$flag_pattern = 1;
			last;
		}
	}
	return($flag_pattern);
}

sub check_width {
	eval 'use Text::VisualWidth::UTF8'; # cpanm
	my($text_ref, $regex_ref) = @_;
	my($i, $flag_sentence, $width, $length, @width, %distribution);
	for ($i = 0; $i < scalar(@$text_ref); $i++) {
		$flag_sentence = 0;
		$width = Text::VisualWidth::UTF8::width($$text_ref[$i]);
		$length = length($$text_ref[$i]);
		if (
				(!($$text_ref[$i] =~ /^(\s|　)*$/)) && 
				((($$regex_ref ne '') && (!($$text_ref[$i] =~ /$$regex_ref/o))) || ($$regex_ref eq ''))
			) {
			if ($width == $length) {
				# 半角のみ
				$flag_sentence = 0;
			} elsif ($width == $length * 2) {
				# 全角のみ
				$flag_sentence = 1;
				$distribution{$width} ++;
			} else {
				# 半角まじり
				$flag_sentence = 1;
			}
		}
		push(@width, [ $flag_sentence, $width ] );
	}
	my @distribution_sort = (sort { $distribution{$b} <=> $distribution{$a} } keys %distribution);
	return(\@width, $distribution_sort[0]);
}

sub tagging_ruby {
	my($text_ref, $flag_ruby) = @_;
	my($ruby_regex);
	if ($flag_ruby eq 'aozora') {
		$ruby_regex = '｜?(\p{InBasicLatin}{1,128}|\p{InCJKSymbolsAndPunctuation}{1,128}|\p{InCJKUnifiedIdeographs}{1,128}|\p{InHalfwidthAndFullwidthForms}{1,128}|\p{InHiragana}{1,128}|\p{InKatakana}{1,128})《([^《]{1,128})》';
	} elsif ($flag_ruby eq 'shincho') { # thanks: http://www.kotono8.com/2005/06/19ruby.html
		$ruby_regex = '#?(\p{InBasicLatin}{1,128}|\p{InCJKSymbolsAndPunctuation}{1,128}|\p{InCJKUnifiedIdeographs}{1,128}|\p{InHalfwidthAndFullwidthForms}{1,128}|\p{InHiragana}{1,128}|\p{InKatakana}{1,128})\{([^\{]{1,128})\}'
	} else {
		return($text_ref);
	}
	$$text_ref =~ s|$ruby_regex|<ruby class="genepub-ruby">$1<rp class="genepub-ruby">（</rp><rt class="genepub-ruby">$2</rt><rp class="genepub-ruby">）</rp></ruby>|go;
	return($text_ref);
}

sub tagging_phone {
	eval 'use Number::Phone::JP'; # cpanm
	my($text_ref) = @_;
	my($phone_regex) = '\(?0[0-9\-\(\)\. ]{8,20}';
	my $phone = Number::Phone::JP->new;
	my(%count, @key, $key, $key_quotemeta);
	@key = grep(!$count{$_}++, ($$text_ref =~ /($phone_regex)/gso));
	while (@key) {
		$key = shift(@key);
		if ($phone->set_number($key)->is_valid_number) {
			$key_quotemeta = quotemeta($key);
			$$text_ref =~ s|$key_quotemeta|<a href="tel:$key" class="genepub-phone">$key</a>|g;
		}
	}
	return($text_ref);
}

sub tagging_zipcode {
	eval 'use Number::ZipCode::JP'; # cpanm
	my($text_ref) = @_;
	my($zipcode_regex) = '\d{3}\-?\d{4}';
	my $zip = Number::ZipCode::JP->new;
	my(%count, @key, $key, $key_quotemeta);
	@key = grep(!$count{$_}++, ($$text_ref =~ /($zipcode_regex)/gso));
	while (@key) {
		$key = shift(@key);
		if ($zip->set_number($key)->is_valid_number) {
			$key_quotemeta = quotemeta($key);
			$$text_ref =~ s|$key_quotemeta|<a href="http://maps.google.co.jp/maps?q=$key" class="genepub-zipcode">$key</a>|g;
		}
	}
	return($text_ref);
}

sub tagging_twitter {
	my($text_ref) = @_;
	my($twitter_regex) = '([^0-9a-zA-Z_])\@([0-9a-zA-Z_]{1,15})';
	$$text_ref =~ s|$twitter_regex|$1<a href="http://twitter.com/$2" class="genepub-twitter">\@$2</a>|g;
	return($text_ref);
}

sub tagging_url { # thanks: http://www.din.or.jp/~ohzaki/perl.htm#AutoLink
	my($str_ref) = @_;
	my($str) = $$str_ref;
	my($http_URL_regex, $ftp_URL_regex, $mail_regex, $tag_regex_, $comment_tag_regex, $tag_regex);
	my($text_regex, $result, $skip, $text_tmp, $tag_tmp);
	$http_URL_regex = # thanks: http://www.din.or.jp/~ohzaki/perl.htm#httpURL
	q{\b(?:https?|shttp)://(?:(?:[-_.!~*'()a-zA-Z0-9;:&=+$,]|%[0-9A-Fa-f} .
	q{][0-9A-Fa-f])*@)?(?:(?:[a-zA-Z0-9](?:[-a-zA-Z0-9]*[a-zA-Z0-9])?\.)} .
	q{*[a-zA-Z](?:[-a-zA-Z0-9]*[a-zA-Z0-9])?\.?|[0-9]+\.[0-9]+\.[0-9]+\.} .
	q{[0-9]+)(?::[0-9]*)?(?:/(?:[-_.!~*'()a-zA-Z0-9:@&=+$,]|%[0-9A-Fa-f]} .
	q{[0-9A-Fa-f])*(?:;(?:[-_.!~*'()a-zA-Z0-9:@&=+$,]|%[0-9A-Fa-f][0-9A-} .
	q{Fa-f])*)*(?:/(?:[-_.!~*'()a-zA-Z0-9:@&=+$,]|%[0-9A-Fa-f][0-9A-Fa-f} .
	q{])*(?:;(?:[-_.!~*'()a-zA-Z0-9:@&=+$,]|%[0-9A-Fa-f][0-9A-Fa-f])*)*)} .
	q{*)?(?:\?(?:[-_.!~*'()a-zA-Z0-9;/?:@&=+$,]|%[0-9A-Fa-f][0-9A-Fa-f])} .
	q{*)?(?:#(?:[-_.!~*'()a-zA-Z0-9;/?:@&=+$,]|%[0-9A-Fa-f][0-9A-Fa-f])*} .
	q{)?};
	$ftp_URL_regex = # thanks: http://www.din.or.jp/~ohzaki/perl.htm#ftpURL
	q{\bftp://(?:(?:[-_.!~*'()a-zA-Z0-9;&=+$,]|%[0-9A-Fa-f][0-9A-Fa-f])*} .
	q{(?::(?:[-_.!~*'()a-zA-Z0-9;&=+$,]|%[0-9A-Fa-f][0-9A-Fa-f])*)?@)?(?} .
	q{:(?:[a-zA-Z0-9](?:[-a-zA-Z0-9]*[a-zA-Z0-9])?\.)*[a-zA-Z](?:[-a-zA-} .
	q{Z0-9]*[a-zA-Z0-9])?\.?|[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)(?::[0-9]*)?} .
	q{(?:/(?:[-_.!~*'()a-zA-Z0-9:@&=+$,]|%[0-9A-Fa-f][0-9A-Fa-f])*(?:/(?} .
	q{:[-_.!~*'()a-zA-Z0-9:@&=+$,]|%[0-9A-Fa-f][0-9A-Fa-f])*)*(?:;type=[} .
	q{AIDaid])?)?(?:\?(?:[-_.!~*'()a-zA-Z0-9;/?:@&=+$,]|%[0-9A-Fa-f][0-9} .
	q{A-Fa-f])*)?(?:#(?:[-_.!~*'()a-zA-Z0-9;/?:@&=+$,]|%[0-9A-Fa-f][0-9A} .
	q{-Fa-f])*)?};
	$mail_regex = # thanks: http://www.din.or.jp/~ohzaki/mail_regex.htm
	q{(?:[-!#-'*+/-9=?A-Z^-~]+(?:\.[-!#-'*+/-9=?A-Z^-~]+)*|"(?:[!#-\[\]-} .
#	q{~]|\\\\[\x09 -~])*")@[-!#-'*+/-9=?A-Z^-~]+(?:\.[-!#-'*+/-9=?A-Z^-~]+} .
	q{~]|\\\\[\x09 -~])*")@[-!#-'*+/-9=?A-Z^-~]+(?:\.[-!#-\x25'*+/-9=?A-Z^-~]+} . # トップドメインに & を含まないように変更
	q{)*};
	$tag_regex_ = q{[^"'<>]*(?:"[^"]*"[^"'<>]*|'[^']*'[^"'<>]*)*(?:>|(?=<)|$(?!\n))}; #'}}}}
	$comment_tag_regex =
		'<!(?:--[^-]*-(?:[^-]+-)*?-(?:[^>-]*(?:-[^>-]+)*?)??)*(?:>|$(?!\n)|--.*$)';
	$tag_regex = qq{$comment_tag_regex|<$tag_regex_};
	$text_regex = q{[^<]*};
	$result = ''; $skip = 0;
	while ($str =~ /($text_regex)($tag_regex)?/gso) {
		last if (!defined($1) and !defined($2));
		$text_tmp = $1;
		$tag_tmp = $2;
		if ($skip) {
			$result .= $text_tmp . $tag_tmp;
			$skip = 0 if $tag_tmp =~ /^<\/[aA](?![0-9A-Za-z])/;
		} else {
			$text_tmp =~ s{($http_URL_regex|$ftp_URL_regex|($mail_regex))}
				{my($org, $mail) = ($1, $2);
					(my $tmp = $org) =~ s/"/&quot;/g;
					'<a href="' . (defined($mail) ? 'mailto:' : '') . $tmp . '" class="' . (defined($mail) ? 'genepub-mailto' : 'genepub-url') . '">' . $org . '</a>'}ego;
			if (defined($tag_tmp)) {
				$result .= $text_tmp . $tag_tmp;
				$skip = 1 if $tag_tmp =~ /^<[aA](?![0-9A-Za-z])/;
				if ($tag_tmp =~ /^<(XMP|PLAINTEXT|SCRIPT)(?![0-9A-Za-z])/i) {
					$str =~ /(.*?(?:<\/$1(?![0-9A-Za-z])$tag_regex_|$))/gsi;
					$result .= $1;
				}
			} else {
				$result .= $text_tmp;
			}
		}
	}
	return(\$result);
}

1;
