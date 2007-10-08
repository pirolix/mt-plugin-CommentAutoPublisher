package MT::Plugin::OMV::CommentAutoPublisher;
# CommentAutoPublisher - Publish the moderated comments automatically
#           Programmed by Piroli YUKARINOMIYA (MagicVox)
#           Open MagicVox.net - http://www.magicvox.net/home
#           @see http://www.magicvox.net/archive/2007/10082054/
use strict;
use MT 3.3;
use MT::Blog;
use MT::Comment;
use MT::Task;
use MT::Util qw( ts2epoch );

use vars qw( $MYNAME $VERSION $VERBOSE );
$MYNAME = 'CommentAutoPublisher';
$VERSION = '1.00';

### Regist myself as a plugin
use base qw( MT::Plugin );
my $plugin = __PACKAGE__->new ({
        name => $MYNAME,
        version => $VERSION,
        author_name => qq{<MT_TRANS phrase="Piroli YUKARINOMIYA">},
        author_link => "http://www.magicvox.net/home.php?$MYNAME",
        doc_link => "http://www.magicvox.net/archive/2007/10082054/?$MYNAME",
        blog_config_template => \&blog_config_template,
        settings => new MT::PluginSettings ([
                ['publish_after', { Default => 0, Scope => 'blog' }],
        ]),
        description => qq{<MT_TRANS phrase="Publish the moderated comments automatically with periodic task manager.">},
});
MT->add_plugin ($plugin);

sub instance { $plugin; }

### Regist my task
MT->add_task (new MT::Task ({
        name => "$MYNAME $VERSION",
        key => "$MYNAME",
        frequency => 60,
        code => \&cb_publish_comments,
}));
MT->run_tasks;



sub blog_config_template {
    my ($plugin, $param, undef) = @_;

    return <<HTMLHEREDOC;
<div class="setting grouped">
  <div class="label">
    <label for="publish_after"><MT_TRANS phrase="Publish after">:</label>
  <!--label--></div>
  <div class="field">
    <input type="text" name="publish_after" id="publish_after" size="5" value="<TMPL_VAR NAME=PUBLISH_AFTER>"/>
    <MT_TRANS phrase="minutes">
    <p>
      <MT_TRANS phrase="Setting '0' means to stop this plugin's function on this blog.">
    </p>
  <!--field--></div>
<!--setting--></div>
HTMLHEREDOC
}



sub cb_publish_comments {
    my $self = shift;
    my $cur_t = time ();

    my $blog_iter = MT::Blog->load_iter ()
        or return;
    while (my $blog = $blog_iter->())
    {
        # Retrieve the plugin setting
        my $publish_after = &instance->get_config_value ('publish_after', 'blog:'. $blog->id)
            or next;
        $publish_after = int ($publish_after)
            or next;

        # for rebuild
        my %need_rebuild = ();

        # All moderated comments will be approved
        my $comment_iter = MT::Comment->load_iter ({
                blog_id => $blog->id,
                visible => 0,
        }) or return;
        while (my $comment = $comment_iter->())
        {
            next if $comment->is_junk;
            next if $cur_t < ts2epoch ($blog, $comment->created_on) + $publish_after * 60;
            # Approve the comment
            $comment->approve;
            $comment->log (qq{ Automatically published by $MYNAME });
            $comment->save
                or die $comment->errstr;
            $need_rebuild{$comment->entry_id} = 1;
        }

        # Rebuild entries which have the updated commments
        foreach my $entry_id (keys %need_rebuild) {
            MT->instance->rebuild_entry (
                    Entry => $entry_id, BlogID => $blog->id, BuildDependencies => 1)
                or next;
        }
    }

    0; # not leave a log
}

1;