<main name="content">
    <div style="width:80%;padding-left:10%">
        <h3>j - journalism for cool people</h3>
        <p>I am WAY too tired to be coding right now. Use this at your own risk. Access tokens are stored in the browser if 'auto-login' is enabled. For the list of things to do: <button onClick={() => {showTodo = !showTodo}}>
        {showTodo? 'hide' : 'show'}
        TODO</button></p>
        
        <div if={showTodo} style="margin-left:5%;width:90%">
            <h1>TODO</h1>
            <ul>
                <li><strike>Get React involved and start creating a login process, forget registration for now</strike><br>NAH let's use RIOT(.js) instead</strike></li>
                <li><strike>Establish a room as a blog. A blog could be 'My cooking blog', and the only admin is the owner of said blog.</strike></li>
                <li><strike>Blog posts are just rich (html formatted) m.room.messages type=text created by the admin, and so get special treatment.</strike></li>
                <li><strike>Other m.room.messages from people in the room are effectively comments, and must somehow refer to the original blog posts. (Maybe something like content.parent = id).</strike></li>
                <li>Show room directory as available blogs from everyone ever. Problem here is that there needs to be a bit of roomState to indicate that it is a blog, otherwise all rooms will appear on this list... Maybe we could regex the room alias for 'blog'? Doing getState on every public room shown is probably a bad thing. But you literally only get visibility from the room directory. So it looks like we'll need something else for searching for blogs.</li>
            </ul>
        </div>

        <button if={isLoggedIn} onClick={doLogout}>logout</button>

        <div if={!isLoggedIn}>
            <p>login here:</p>
            <input type="text" name="user_id" placeholder="@person1234:matrix.org"/></br>
            <input type="password" name="password" placeholder="password" /></br>
            
            <label>auto-login next time:</label>
            <input type="checkbox" name="shouldRememberMe"/><br>
            <button onClick={doLoginWithPassword}>login</button>
        </div>

        <div if={isLoggedIn}>
            <input type="text" name="room_name" placeholder="My First Mlog"/>
            <button onClick={doCreateBlog}>Create Blog</button>
            <input type="text" name="view_room_id" placeholder="!roomtoview:matrix.org" value="!qJXdPYrthkbuFjdrxj:matrix.org"/>
            <button onClick={()=>{
            riot.route('/journal/' + view_room_id.value)}}>View Blog</button>

            <div each={entries}>
                <blog 
                    mine={isMine} if={isBlogPost} content={html}
                    delete={deleteEntry} comment={comment}
                />
            </div>

            <div if={entries.length==0} style="text-align:center">
                ---------------------no blogs yet---------------------
            </div>

            <div if={isOwnerOfCurrentBlog}>
                <h2>Create a new blog post here:</h2>
                <div 
                    contenteditable="true" 
                    name="new_blog_post_content" 
                    style="background-color:#fff; color:#333; border-radius:5px;border:1px solid #ccc; outline:0px; padding:5px"
                ></div>
                <button onClick={doNewBlogPost}>Post</button>
            </div>
        </div>
    </div>
    <script>
        let self = this;
        const matrixSdk = require('matrix-js-sdk');
        let l = riot.route.create();
        l(
            '/journal/*',
            (nroom_id) => {
                console.log('Now viewing ', nroom_id);
                self.view_room_id.value = nroom_id;
                doViewBlog().catch(console.error);
            }
        );

        let hsUrl = "https://matrix.org";

        let cli = matrixSdk.createClient({
           baseUrl: hsUrl
        });

        var doCreateBlog = () => {
            cli.createRoom({
                visibility: 'public',
                name: self.room_name.value
            }).then((resp) => {
                self.view_room_id.value = resp.room_id;
                doViewBlog().catch(console.error);
            });
        }

        // let entries = []; // Blog posts and comments
        let admins = []; // Authors of the current blog

        let events = {};
        let rooms = {};
        let creds = null;

        let access_token = null;
            
        // Initial loaded state
        self.update({
            entries: [], 
            canCreateNewPost: false, 
            isLoggedIn: false}
        );

        let ueDebounce = null;
        let updateEntriesDebounce = (delay) => {
            clearTimeout(ueDebounce);
            ueDebounce = setTimeout(
                updateEntries, delay
            );
        };

        let updateEntries = () => {
            console.log('updateEntries');
            if (!events[self.view_room_id.value]) {
                return; // No events yet
            }

            let entries = events[self.view_room_id.value];
            
            entries = entries.filter((e) => {
                return e.event.type === 'm.room.message'
                    && e.event.content.parent === undefined; // remove comments
            }).sort((a,b) => b.getTs() - a.getTs());

            // Transform into view
            entries = entries.map((e) => {
                let isBlogPost = e.event.content.format === 'org.matrix.custom.html';
                isBlogPost = isBlogPost && (admins.indexOf(e.event.sender) !== -1);
                let comments = events[self.view_room_id.value].filter(
                        (e2) => e2.event.content.parent === e.getId()
                ).map(
                    (e2) => {
                        return { 
                            content : e2.event.content.body,
                            id : e2.getId(),
                            isMine : e2.getSender() === creds.user_id,

                            deleteEntry : () => {
                                doDeleteEntry(e2.getId());
                            },

                            sender : e2.getSender()
                        };
                    }
                );

                return {
                    id : e.getId(),
                    isMine : e.event.sender === creds.user_id,
                    isBlogPost : isBlogPost,
                    // TODO: sanitise self
                    html : e.event.content.formatted_body,
                    text : e.event.content.body,

                    comments : comments,

                    deleteEntry : () => {
                        doDeleteEntry(e.getId());
                    },

                    comment : function () {
                        doNewComment(
                            e.getId(), 
                            self.comment_text.value
                        );
                    }
                }
            });

            self.update({entries: entries});
        }

        doNewBlogPost = () => {
            let body = self.new_blog_post_content.innerHTML;
            console.log(body);
            body = body.split('<br>');

            body[0] = '<h1>' + body[0] + '</h1><p>';
            body = body.join('</p><p>') + '<p>';

            cli.sendMessage(
                self.view_room_id.value,
                {
                    msgtype: 'm.text',
                    body: 'no plaintext',
                    format: 'org.matrix.custom.html',
                    // TODO: sanitise self
                    formatted_body: body,
                }
            );

        } 

        doViewBlog = () => {
            console.log('Viewing ',self.view_room_id.value);

            cli.joinRoom(self.view_room_id.value, {
                syncRoom: true
            });

            rooms[self.view_room_id.value] = cli.getRoom(self.view_room_id.value);

            return cli.getStateEvent(self.view_room_id.value, 'm.room.power_levels').then(
                (powerLevels) => {
                    admins = Object.keys(powerLevels.users).filter((uid) => powerLevels.users[uid] >= 100
                    );
                    self.update({
                        isOwnerOfCurrentBlog: admins.indexOf(creds.user_id) !== -1
                    });
                    updateEntriesDebounce(1000);
                }
            ).catch(console.error);
        }

        doDeleteEntry = (id) => {
            console.log('redacting...');
            return cli.redactEvent(self.view_room_id.value, id).done(
                () => {
                    console.log('Redacted');
                }
            );
        }

        doNewComment = (id, text) => {
            console.log('commenting...');
            return cli.sendMessage(
                self.view_room_id.value,
                {
                    msgtype: 'm.text',
                    body: text,
                    parent: id
                }
            );
        }

        doLoginWithPassword = () => {
            localStorage.setItem("auto_login", self.shouldRememberMe.checked);
            cli.loginWithPassword(
                self.user_id.value, self.password.value
            ).done((resp) => {
                cli = matrixSdk.createClient({
                   baseUrl: hsUrl,
                   accessToken: resp.access_token,
                   userId: resp.user_id
                });
                loggedIn(resp);
            });
        };

        doLoginWithOpts = (opts) => {

            cli = matrixSdk.createClient({
               baseUrl: hsUrl,
               accessToken: opts.access_token,
               userId: opts.user_id
            }); 

            loggedIn(opts);
        };

        let loggedIn = (loginCreds) => {
            creds = loginCreds;
            if (localStorage.getItem("auto_login")) {
                console.log('Storing access token and user id');
                localStorage.setItem("mx_access_token", creds.access_token);
                localStorage.setItem("mx_user_id", creds.user_id);
            } else {
                self.user_id.value = "";
                self.password.value = "";
            }

            //TODO: Hook these on load, not on login
            cli.on("event", (e) => {
                if (!events[e.getRoomId()]) events[e.getRoomId()] = [];

                // No duplicates
                if (!events[e.getRoomId()].find((e2) => {
                    return e2.getId() === e.getId()
                })) {
                    events[e.getRoomId()].push(e);
                }

                if (e.getRoomId() === self.view_room_id.value) {
                    updateEntriesDebounce(1000);
                }
            });
            cli.on("Room.redaction", function(e) {
                console.log('redaction received');
            });

            self.update({isLoggedIn: true});
            console.log('Logged in!');

            cli.startClient();
            doViewBlog().catch(console.error);
        }

        doLogout = () => {
            localStorage.removeItem("mx_access_token");
            localStorage.removeItem("mx_user_id");
            // riot.route('/');
            self.update({isLoggedIn: false});
        }

        showTodo = false;

        console.log('Routing starting...');
        riot.route.start();
        riot.route.exec();

        if (localStorage) {
            access_token = localStorage.getItem("mx_access_token");
            user_id = localStorage.getItem("mx_user_id");

            if (access_token && user_id) {
                doLoginWithOpts({
                    access_token: access_token,
                    user_id: user_id
                });
            }
        }
    </script>
</main>