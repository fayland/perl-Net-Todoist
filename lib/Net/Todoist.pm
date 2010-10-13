package Net::Todoist;

# ABSTRACT: Todoist API

use strict;
use warnings;
use LWP::UserAgent;
use JSON::XS;
use Carp 'croak';
use vars qw/$errstr/;

=head1 SYNOPSIS
 
    use Net::Todoist;
    
    my $nt = Net::Todoist->new( token => $token );
    
    # or use login to get the token
    my $nt = Net::Todoist->new();
    my $user = $nt->login($email, $pass) or die "login failed: " . $nt->errstr;
    # or use register to set the token
    my $nt = Net::Todoist->new();
    my $user = $nt->register(
        email => $email,
        full_name => 'Fayland Lam',
        password  => 'guessitplz',
        timezone  => "GMT +8:00"
    ) or die "Can't register: " . $nt->errstr;
    
    ## updateUser

=head1 DESCRIPTION

read L<http://todoist.com/API/help> for more details.

=head2 METHODS

=head3 CONSTRUCTION

    my $nt = Net::Todoist->new( token => $token );

=over 4

=item * token (optional)

the API token from L<http://todoist.com>

=item * ua_args

passed to LWP::UserAgent

=item * ua

L<LWP::UserAgent> or L<WWW::Mechanize> instance

=back

=cut

sub new {
    my $class = shift;
    my $args = scalar @_ % 2 ? shift : { @_ };

    unless ( $args->{ua} ) {
        my $ua_args = delete $args->{ua_args} || {};
        $args->{ua} = LWP::UserAgent->new(%$ua_args);
    }
    unless ($args->{json}) {
        $args->{json} = JSON::XS->new->utf8->allow_nonref;
    }

    bless $args, $class;
}

sub errstr { $errstr };

=pod

=head3 login

    my $user = $nt->login($email, $pass) or die "login failed: " . $nt->errstr;

you don't need call ->login if you pass the B<token> in the ->new

=cut

sub login {
    my ($self, $email, $pass) = @_;
    
    my $resp = $self->{ua}->post('https://todoist.com/API/login', [
        email => $email,
        password => $pass
    ] );
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    if ($resp->content =~ 'LOGIN_ERROR') {
        $errstr = $resp->content;
        return;
    }

    my $data = $self->{json}->decode($resp->content);
    $self->{token} = $data->{api_token};
    return $data;
}

=pod

=head3 getTimezones

    my @timezone = $nt->getTimezones();

Returns the timezones Todoist supports.

=cut

sub getTimezones {
    my ($self) = @_;
    
    my $resp = $self->{ua}->get('http://todoist.com/API/getTimezones');
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    my $data = $self->{json}->decode($resp->content);
    return wantarray ? @$data : $data;
}

=pod

=head3 register

    my $user = $nt->register(
        email => $email,
        full_name => 'Fayland Lam',
        password  => 'guessitplz',
        timezone  => "GMT +8:00"
    ) or die "Can't register: " . $nt->errstr;

=cut

sub register {
    my $self = shift;
    my $args = scalar @_ % 2 ? shift : { @_ };
    
    my $resp = $self->{ua}->post('https://todoist.com/API/register', [
        email => $args->{email},
        full_name => $args->{full_name},
        password => $args->{password} || $args->{pass},
        timezone => $args->{timezone}
    ] );
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    unless ($resp->content =~ 'api_token') {
        $errstr = $resp->content;
        return;
    }

    my $data = $self->{json}->decode($resp->content);
    $self->{token} = $data->{api_token};
    return $data;
}

=pod

=head3 updateUser

    my $user = $nt->updateUser(
        email => $email,
        full_name => 'Fayland Lam',
        password  => 'guessitplz',
        timezone  => "GMT +8:00"
    ) or die "Can't update: " . $nt->errstr;

=cut

sub updateUser {
    my $self = shift;
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    
    my $args = scalar @_ % 2 ? shift : { @_ };
    
    my $resp = $self->{ua}->post('https://todoist.com/API/updateUser', [
        token => $self->{token},
        email => $args->{email},
        full_name => $args->{full_name},
        password => $args->{password} || $args->{pass},
        timezone => $args->{timezone}
    ] );
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    unless ($resp->content =~ 'api_token') {
        $errstr = $resp->content;
        return;
    }

    my $data = $self->{json}->decode($resp->content);
    return $data;
}

=pod

=head3 getProjects

    my @projects = $nt->getProjects;

=cut

sub getProjects {
    my $self = shift;
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    
    my $resp = $self->{ua}->get("http://todoist.com/API/getProjects?token=$self->{token}");
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    my $data = $self->{json}->decode($resp->content);
    return wantarray ? @$data : $data;
}

=pod

=head3 getProject

    my $project = $nt->getProject($project_id);

=cut

sub getProject {
    my ($self, $project_id) = @_;
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    
    my $resp = $self->{ua}->get("http://todoist.com/API/getProject?token=$self->{token}&project_id=$project_id");
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    my $data = $self->{json}->decode($resp->content);
    return $data;
}

=pod

=head3 addProject

    my $project = $nt->addProject(
        name => $name, # required
        color => $color, # optional
        indent => $indent, # optional
        order => $order, # optional
    ) or die "Can't addProject: " . $nt->errstr;

=cut

sub addProject {
    my $self = shift;
    my $args = scalar @_ % 2 ? shift : { @_ };
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    defined $args->{name} or croak 'name is required.';
        
    my $resp = $self->{ua}->post('https://todoist.com/API/addProject', [
        token => $self->{token},
        name => $args->{name},
        $args->{color} ? (color => $args->{color}) : (),
        $args->{indent} ? (indent => $args->{indent}) : (),
        $args->{order} ? (order => $args->{order}) : (),
    ] );
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    if ($resp->content =~ 'ERROR_NAME_IS_EMPTY') {
        $errstr = $resp->content;
        return;
    }

    my $data = $self->{json}->decode($resp->content);
    return $data;
}

=pod

=head3 updateProject

    my $project = $nt->updateProject(
        proejct_id => $proejct_id, # required
        
        name => $name, # optional
        color => $color, # optional
        indent => $indent, # optional
    ) or die "Can't updateProject: " . $nt->errstr;

=cut

sub updateProject {
    my $self = shift;
    my $args = scalar @_ % 2 ? shift : { @_ };
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    defined $args->{proejct_id} or croak 'proejct_id is required.';
        
    my $resp = $self->{ua}->post('https://todoist.com/API/updateProject', [
        token => $self->{token},
        proejct_id => $args->{proejct_id},
        $args->{name} ? (order => $args->{name}) : (),
        $args->{color} ? (color => $args->{color}) : (),
        $args->{indent} ? (indent => $args->{indent}) : (),
    ] );
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    if ($resp->content =~ 'ERROR_PROJECT_NOT_FOUND') {
        $errstr = $resp->content;
        return;
    }

    my $data = $self->{json}->decode($resp->content);
    return $data;
}

=pod

=head3 deleteProject

    my $is_deleted_ok = $self->deleteProject($project_id) or die "Connection issue: " . $nt->errstr;

=cut

sub deleteProject {
    my ($self, $project_id) = @_;
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    
    my $resp = $self->{ua}->get("http://todoist.com/API/deleteProject?token=$self->{token}&project_id=$project_id");
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    return ($resp->content =~ /ok/i) ? 1 : 0;
}

=pod

=head3 getLabels

    my @labels = $nt->getLabels or die "Can't get labels: " . $nt->errstr;
    
=cut

sub getLabels {
    my $self = shift;
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    
    my $resp = $self->{ua}->get("http://todoist.com/API/getLabels?token=$self->{token}");
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    my $data = $self->{json}->decode($resp->content);
    return wantarray ? @$data : $data;
}

=pod

=head3 updateLabel

    my $update_ok = $nt->updateLabel(
        old_name => $old_name, # required
        new_name => $new_name, # required
    ) or die "Can't updateLabel: " . $nt->errstr;

=cut

sub updateLabel {
    my $self = shift;
    my $args = scalar @_ % 2 ? shift : { @_ };
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    defined $args->{old_name} or croak 'old_name is required.';
    defined $args->{new_name} or croak 'new_name is required.';
        
    my $resp = $self->{ua}->post('https://todoist.com/API/updateLabel', [
        token => $self->{token},
        old_name => $args->{old_name},
        new_name => $args->{new_name},
    ] );
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    return ($resp->content =~ /ok/i) ? 1 : 0;
}

=pod

=head3 deleteLabel

    my $is_deleted_ok = $self->deleteLabel($name) or die "Connection issue: " . $nt->errstr;

=cut

sub deleteLabel {
    my ($self, $name) = @_;
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    
    my $resp = $self->{ua}->get("http://todoist.com/API/deleteLabel?token=$self->{token}&name=$name");
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    return ($resp->content =~ /ok/i) ? 1 : 0;
}

=pod

=head3 getUncompletedItems

    my @items = $nt->getUncompletedItems($project_id) or die "Can't getUncompletedItems: " . $nt->errstr;
    # js_date is optional, bool
    $nt->getUncompletedItems($project_id, $js_date);
    
=cut

sub getUncompletedItems {
    my ($self, $project_id, $js_date) = @_;
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    
    my $url = "http://todoist.com/API/getUncompletedItems?token=$self->{token}&project_id=$project_id";
    $url .= '&js_date=1' if $js_date;
    my $resp = $self->{ua}->get($url);
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    my $data = $self->{json}->decode($resp->content);
    return wantarray ? @$data : $data;
}

=pod

=head3 getCompletedItems

    my @items = $nt->getCompletedItems($project_id) or die "Can't getCompletedItems: " . $nt->errstr;
    # js_date is optional, bool
    $nt->getCompletedItems($project_id, $js_date);
    
=cut

sub getCompletedItems {
    my ($self, $project_id, $js_date) = @_;
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    
    my $url = "http://todoist.com/API/getCompletedItems?token=$self->{token}&project_id=$project_id";
    $url .= '&js_date=1' if $js_date;
    my $resp = $self->{ua}->get($url);
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    my $data = $self->{json}->decode($resp->content);
    return wantarray ? @$data : $data;
}

=pod

=head3 getItemsById

    my @items = $nt->getItemsById( [210873,210874] ) or die "Can't getItemsById: " . $nt->errstr;
    # js_date is optional, bool
    $nt->getItemsById( \@item_ids, $js_date);

=cut

sub getItemsById {
    my ($self, $item_ids, $js_date) = @_;
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    
    $item_ids = [$item_ids] unless ref $item_ids eq 'ARRAY';
    
    my $url = "http://todoist.com/API/getItemsById?token=$self->{token}&ids=[" . join(',', @$item_ids) . ']';
    $url .= '&js_date=1' if $js_date;
    my $resp = $self->{ua}->get($url);
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    my $data = $self->{json}->decode($resp->content);
    return wantarray ? @$data : $data;
}

=pod

=head3 addItem

    my $item = $nt->addItem(
        proejct_id => $proejct_id, # required
        content => $content, # required
        date_string => $date_string, # optional
        priority => $priority, # optional
        js_date => $js_date, # optional
    ) or die "Can't addProject: " . $nt->errstr;

=cut

sub addItem {
    my $self = shift;
    my $args = scalar @_ % 2 ? shift : { @_ };
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    defined $args->{proejct_id} or croak 'proejct_id is required.';
    defined $args->{content} or croak 'content is required.';
        
    my $resp = $self->{ua}->post('https://todoist.com/API/addItem', [
        token => $self->{token},
        proejct_id => $args->{proejct_id},
        content => $args->{content},
        $args->{date_string} ? (date_string => $args->{date_string}) : (),
        $args->{priority} ? (priority => $args->{priority}) : (),
        $args->{js_date} ? (js_date => $args->{js_date}) : (),
    ] );
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    unless ($resp->content =~ 'id') {
        $errstr = $resp->content;
        return;
    }

    my $data = $self->{json}->decode($resp->content);
    return $data;
}

=pod

=head3 updateItem

    my $item = $nt->updateItem(
        id => $item_id, # required
        
        content => $content, # optional
        date_string => $date_string, # optional
        priority => $priority, # optional
        indent => $indent, # optional
        item_order => $item_order, # optional
        js_date => $js_date, # optional
    ) or die "Can't updateProject: " . $nt->errstr;

=cut

sub updateItem {
    my $self = shift;
    my $args = scalar @_ % 2 ? shift : { @_ };
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    defined $args->{id} or croak 'id is required.';
        
    my $resp = $self->{ua}->post('https://todoist.com/API/updateItem', [
        token => $self->{token},
        id => $args->{id},
        $args->{content} ? (content => $args->{content}) : (),
        $args->{date_string} ? (date_string => $args->{date_string}) : (),
        $args->{priority} ? (priority => $args->{priority}) : (),
        $args->{indent} ? (indent => $args->{indent}) : (),
        $args->{item_order} ? (item_order => $args->{item_order}) : (),
        $args->{js_date} ? (js_date => $args->{js_date}) : (),
    ] );
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    unless ($resp->content =~ 'id') {
        $errstr = $resp->content;
        return;
    }

    my $data = $self->{json}->decode($resp->content);
    return $data;
}

=pod

=head3 updateOrders

    my $update_ok = $nt->updateOrders( $project_id, \@item_ids ) or die "Can't updateOrders: " . $nt->errstr;

=cut

sub updateOrders {
    my ($self, $project_id, $item_ids) = @_;
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    defined $args->{project_id} or croak 'project_id is required.';
    
    $item_ids = [$item_ids] unless ref $item_ids eq 'ARRAY';
    
    my $url = "http://todoist.com/API/updateOrders?token=$self->{token}&project_id=$project_id&item_id_list=[" . join(',', @$item_ids) . ']';
    my $resp = $self->{ua}->get($url);
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    return ($resp->content =~ /ok/i) ? 1 : 0;
}

=pod

=head3 updateRecurringDate

    # js_date is optional
    my @items = $nt->updateRecurringDate( \@item_ids, $js_date )
        or die "Can't updateRecurringDate: " . $nt->errstr;

=cut

sub updateRecurringDate {
    my ($self, $item_ids, $js_date) = @_;
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    
    $item_ids = [$item_ids] unless ref $item_ids eq 'ARRAY';
    
    my $url = "http://todoist.com/API/updateRecurringDate?token=$self->{token}&ids=[" . join(',', @$item_ids) . ']';
    $url .= '&js_date=1' if $js_date;
    my $resp = $self->{ua}->get($url);
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    my $data = $self->{json}->decode($resp->content);
    return wantarray ? @$data : $data;
}

=pod

=head3 deleteItems

    my $is_deleted = $nt->deleteItems(@item_ids);
    my $is_deleted = $nt->deleteItems(\@item_ids);
    
=cut

sub deleteItems {
    my ($self, @item_ids) = @_;
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    @item_ids = @{ $item_ids[0] } if scalar(@item_ids) == 2 and ref $item_ids[0] eq 'ARRAY';

    my $url = "http://todoist.com/API/deleteItems?token=$self->{token}&ids=[" . join(',', @item_ids) . ']';
    my $resp = $self->{ua}->get($url);
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    return ($resp->content =~ /ok/i) ? 1 : 0;
}

=pod

=head3 completeItems

    # in_history is optional, default as 1
    my $is_ok = $nt->completeItems(\@item_ids, $in_history) or die "Can't completeItems: " . $nt->errstr;

=cut

sub completeItems {
    my ($self, $item_ids, $in_history) = @_;
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    $item_ids = [$item_ids] unless ref $item_ids eq 'ARRAY';
    
    my $url = "http://todoist.com/API/completeItems?token=$self->{token}&ids=[" . join(',', @$item_ids) . ']';
    $url .= '&in_history=1' if $in_history;
    my $resp = $self->{ua}->get($url);
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    return ($resp->content =~ /ok/i) ? 1 : 0;
}

=pod

=head3 uncompleteItems

    my $is_ok = $nt->uncompleteItems(@item_ids);
    my $is_ok = $nt->uncompleteItems(\@item_ids);
    
=cut

sub uncompleteItems {
    my ($self, @item_ids) = @_;
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    @item_ids = @{ $item_ids[0] } if scalar(@item_ids) == 2 and ref $item_ids[0] eq 'ARRAY';

    my $url = "http://todoist.com/API/uncompleteItems?token=$self->{token}&ids=[" . join(',', @item_ids) . ']';
    my $resp = $self->{ua}->get($url);
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }
    
    return ($resp->content =~ /ok/i) ? 1 : 0;
}

=pod

=head3 query

    my @items = $nt->query(
        queries => ["2007-4-29T10:13","overdue","p1","p2"], # required
        as_count => 0, # optional
        js_date  => 0, # optional
    )

=cut

sub query {
    my $self = shift;
    my $args = scalar @_ % 2 ? shift : { @_ };
    
    # validate
    defined $self->{token} or croak 'token must be passed to ->new, or call ->login, ->register before this.';
    defined $args->{queries} or croak 'queries is required.';
    my $queries = $args->{queries};
    $queries = [$queries] unless ref $queries eq 'ARRAY';
        
    my $resp = $self->{ua}->post('https://todoist.com/API/query', [
        token => $self->{token},
        queries => '[' . join(',', @$queries) . ']',
        $args->{as_count} ? (as_count => $args->{as_count}) : (),
        $args->{js_date} ? (js_date => $args->{js_date}) : (),
    ] );
    unless ($resp->is_success) {
        $errstr = $resp->status_line;
        return;
    }

    my $data = $self->{json}->decode($resp->content);
    return wantarray ? @$data : $data;
}

1;
