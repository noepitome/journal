<editor>
    <textarea
        id={opts.taid}
        name={opts.taname}
        ref="ta"
    ></textarea>
    <button onClick={() => {this.submit()}}>spread the word</button>

    var marked = require("marked");
    marked.setOptions({
        sanitize: true, // Sanitize the output of marked, this does not protect against XSS
    });
    var SimpleMDE = require("simplemde");

    this.submit = function() {
        let md = marked(this.simplemde.value());
            opts.submit(md).then(
            () => {
                this.simplemde.value("");
            }
        );
    }

    this.on('mount', () => {
        this.simplemde = new SimpleMDE({
            element: document.getElementById(opts.taid),
            autofocus: true,
        });
    });
</editor>

<editable>
    <span>
        {this.opts.prefix}<input
            contenteditable="true"
            class="j_text_input"
            onchange={onChange}
            value={this.opts.initialValue}
            placeholder={this.opts.placeholder}
            if={this.opts.enabled}
        /><span if={!this.opts.enabled}>{this.opts.initialValue}</span>{this.opts.suffix}
    </span>
</editable>

<aliasInput>
    <editable
        prefix={window.location.origin + '/#/journal/'}
        suffix={':' + this.opts.domain}
        onChange={onChange}
        initial-value={this.opts.initialValue}
        placeholder="my-blog"
        enabled={this.opts.enabled}
    />

    onChange(e) {
        if (e.target.value) {
            dis.dispatch({
                type: 'alias_change',
                payload: {
                    value: '#' + e.target.value + ':' + this.opts.domain,
                },
            });
        }
    }
</aliasInput>

<loginPanel>
    <h1 style="text-align:center">login with <a href="http://matrix.org">[matrix]</a> to use journal</h1>
    <div class="j_login_form">
        <div>
            <label for="user_id">
                user ID:
            </label>
            <input type="text" name="user_id" ref="user_id" placeholder="@person1234:matrix.org" value={userId}/>
        </div><div>
            <label for="password">
                password:
            </label>
            <input
                type="password"
                name="password"
                ref="password"
                placeholder="password"
            />
        </div><div>
            <label for="homeserver_url_input">
                homeserver:
            </label>
            <input type="text" name="homeserver_url_input" ref="homeserver_url_input" placeholder="https://matrix.org" value={homeserverUrl}/>
        </div>
        <div>
            <label for="remember_me">
                auto-login next time*:
            </label>
            <input type="checkbox" name="remember_me" ref="remember_me" style="float:right" checked={rememberMe}/>
        </div>
        <p>
            *access tokens are stored in the browser if enabled.
        </p>
        <div style="text-align: center">
            <button onClick={doLoginWithPassword}>login</button>
            <p style="text-align: center">or</p>
            <button onClick={doLoginAsGuest}>login as guest</button>
        </div>
    </div>
    <script>
        this.userId = localStorage.getItem('mx_user_id');
        this.homeserverUrl = localStorage.getItem('mx_hs') || "https://matrix.org";
        this.rememberMe = localStorage.getItem('auto_login');

        doLoginWithPassword(e) {
            dis.dispatch({
                type: 'login_password',
                payload: {
                    userId: this.refs.user_id.value,
                    password: this.refs.password.value,
                    homeserverUrl: this.refs.homeserver_url_input.value,
                    rememberMe: this.refs.remember_me.value,
                }
            });
        }

        doLoginAsGuest(e) {
            dis.dispatch({
                type: 'login_guest',
                payload: {
                    homeserverUrl: this.refs.homeserver_url_input.value,
                }
            });
        }
    </script>
</loginPanel>

<topBar>
    <span style="float:right">
        logged in as {loggedInAs}
        <button onClick={doLogout}>logout</button>
    </span>
    <div style="clear:both">
        <span if={this.opts.roomList.length !== 0}>
        visited:</span>
        <span each={this.opts.roomList} style="padding-right:10px">
            <a href="/#/journal/{roomId}">{name}</a>
        </span>
    </div>
    loggedInAs = this.opts.loggedInAs;

    doLogout(e) {
        dis.dispatch({
            type: 'logout',
        });
    }
</topBar>

<main name="content">
    <div class="j_container">
        <strong>
            <a href="https://github.com/lukebarnard1/journal">journal - a blogging platform built on [matrix]</a>
        </strong>
        <topBar if={isLoggedIn} room-list={roomList} logged-in-as={userId}/>

        <loginPanel if={!isLoggedIn}/>

        <div if={isLoggedIn}>
            <button onClick={()=>{this.showCreateRoomForm = !this.showCreateRoomForm}}>{this.showCreateRoomForm?'hide':'create your own blog'}</button>
            <button if={isOwnerOfCurrentBlog} onClick={()=>{this.showCreateBlogForm = !this.showCreateBlogForm}}>{this.showCreateBlogForm?'hide':'write a new blog post'}</button>
            <div if={showCreateRoomForm}>
                <input type="text" name="room_name_input" placeholder="blog title"/>
                <select name="room_join_rule_input">
                    <option value="public_chat" selected="selected">public</option>
                    <option value="private_chat">private</option>
                </select>
                <button onClick={doCreateBlog}>create blog</button>
            </div>
            <div if={currentRoom} class="j_blog_header">
                <img if={room_avatar_url} src={room_avatar_url}/>
                <h1>{currentRoom.name}</h1>
                <div class="j_blog_topic">
                    <editable
                        initial-value={currentRoom.topic}
                        placeholder="The topic of your blog"
                        enabled={isOwnerOfCurrentBlog}
                    />
                </div>
                <div>
                    <aliasInput enabled={isOwnerOfCurrentBlog} domain={domain} initial-value={aliasInputValue}/>
                </div>
                <small if={currentRoom.subscribers}>{currentRoom.subscribers} people subscribed</small>
            </div>
            <div if={isOwnerOfCurrentBlog && showCreateBlogForm}>
                <editor taid="main-editor" taname="new_blog_post_content" submit={doNewBlogPost}/>
            </div>
            <blog each={entries}></blog>
            <div if={entries.length==0} style="text-align:center">
                {noBlogsMsg}
            </div>
        </div>
    </div>

    this.on('mount', () => {
        require('../logic/main.js')(this);
    });
</main>
