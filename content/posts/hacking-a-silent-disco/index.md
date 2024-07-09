+++
title = "Hacking a Silent Disco"
date = "2023-10-21"

[taxonomies]
tags=["reverse engineering"]
+++

# Introduction

A while ago while I was partying at a silent disco bar, I noticed something interesting: They have a digital jukebox - basically a website that lets people choose which music should be played. People can add songs or vote for existing ones. The song with the most votes will be played next.

I tried to add [my own song](https://www.youtube.com/watch?v=dQw4w9WgXcQ), but I didn't get any votes so I did the only logical thing: I reverse engineered the website and wrote a bot to vote for my song.

![](./rick-astley-kiosk.jpeg)

# How does it work?

Let's take a step back. How does the Jukebox even work? It's quite straightforward. You go to the website and add the song you want or vote for other songs:

<div style="width:100%;height:0px;position:relative;padding-bottom:64.923%;"><iframe src="https://streamable.com/e/nt1ogw" frameborder="0" width="100%" height="100%" allowfullscreen style="width:100%;height:100%;position:absolute;left:0px;top:0px;overflow:hidden;"></iframe></div>

# Reverse Engineering it

Since it's a web app, the first thing I looked at was the network requests. I quickly realized, they are using websockets, since I saw no network requests when voting. After finding the `wss://s-usc1f-nss-2524.firebaseio.com/.ws?v=5&ns=festify-79b08` websocket request, I was able to view all the messages:

<div style="width:100%;height:0px;position:relative;padding-bottom:64.923%;"><iframe src="https://streamable.com/e/z40fhm" frameborder="0" width="100%" height="100%" allowfullscreen style="width:100%;height:100%;position:absolute;left:0px;top:0px;overflow:hidden;"></iframe></div>

The JSON data looked strange, and only parts made sense so I searched for it on the internet. I then found out that they are using a [Firebase Realtime Database](https://firebase.google.com/docs/database) to store the data.

# Firebase Realtime Database Wire Protocol 

Turns out, the websocket is part of the undocumented Firebase Wire Protocol. Luckily, some people have already reverse engineered it and documented some parts. Why? Writing a custom backend is useful when Google could kill Firebase tomorrow and add it to their [graveyard](https://killedbygoogle.com/).

## Encoding

All the websocket messages are JSON encoded. They only use single letter names, which makes it hard to understand but reduces the total amount of space per message. Luckily, the [iOS SDK](https://github.com/firebase/firebase-ios-sdk/blob/7502fe3d09c23a90938bdd18ca0c2b64d711ec32/FirebaseDatabase/Sources/Constants/FConstants.m) documented them in a single file. 

I'll use the following format in this article: 
- The original name of the field is denoted in brackets (e.g. `t` for `[t]ype`) 
- Values that are not fixed are denoted with `<...>` (e.g. `<data_msg>`)
- Fixed values will be shown as strings or numbers.

The JSON message is wrapped in a data message envelope, which is used to send arbitrary data messages to the server.
```json
{
  "[t]ype": "data",
  "[d]ata": <data_msg>
}
```
<!-- See: https://github.com/firebase/firebase-js-sdk/blob/cbfd14cfb27cda8a6de74be5d138ea9e6de09fe9/packages/database/src/realtime/Connection.ts#L223-L227 -->

The data message will always have the following format. If the data message is a response, the action field is excluded. The request number is a sequential number used to match requests and responses.
```json
{
  "[r]equest_num": <1337>,
  "[a]ction": <action>,
  "[b]ody": <body>
}
```
<!-- https://github.com/firebase/firebase-js-sdk/blob/cbfd14cfb27cda8a6de74be5d138ea9e6de09fe9/packages/database/src/core/PersistentConnection.ts#L182C54-L182C54 -->

The total body for each message, looks like this:

```json
{
  "[t]ype": "data",
  "[d]ata": {
    "[r]equest_num": <1337>,
    "[a]ction": <action>,
    "[b]ody": <body>
  }
}
```

For the sake of readability, only the body will be shown in the following examples.

## Auth Request

<details>
  <summary>Metadata</summary>
  
  - Action: `auth`
</details>

---

To be able to operate on the database, you need to authenticate. The permissions and paths can be configured for every Firebase project in a [database.rules.bolt](https://github.com/Festify/app/blob/develop/database.rules.bolt) file. 

The body contains the [id_token](https://openid.net/specs/openid-connect-core-1_0.html#IDToken) generated via the Firebase REST API (see [next section](#sign-in)), which looks like this: 

```json
{
  "cred": <id_token>
}
```

The response includes the `user_id`, `id_token` and other information. Only the `user_id` is needed for further requests.

```json
{
  "status": "ok",
  "data": {
    "auth": {
      "provider": "anonymous",
      "provider_id": "anonymous",
      "user_id": "482MnymvNFU63WRznog2yPEq4Vz2",
      "token": <id_token>,
      "uid": "482MnymvNFU63WRznog2yPEq4Vz2"
    },
    "expires": 1695466112
  }
}
```

### Sign in anonymously {#sign-in}

Firebase uses [OpenID Connect](https://openid.net/connect/) for authentication. The `anonymous` provider is used to sign in anonymously. To generate an `id_token` and `refresh_token`, we can use the [Firebase Auth REST API](https://firebase.google.com/docs/reference/rest/auth).

```bash
curl 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=<censored>' \
  -H 'Content-Type: application/json' \
  --data-binary '{"returnSecureToken":true}' \
  --referer https://festify.us/
```

We need to modify the referer header, otherwise our request will be blocked. This is a security feature, but can be easily bypassed. Fun fact: The referer header [can't be set in a browser](https://developer.mozilla.org/en-US/docs/Glossary/Forbidden_header_name) (which is probably a good thing). 

The response will contain the `id_token` which can be used to authenticate:

```json
{
  "idToken": <id_token>,
  "email": "",
  "refreshToken": <refresh_token>,
  "expiresIn": "3600",
  "localId": <local_id>
}
```

### Exchange Refresh Token

The `id_token` is valid for one hour. To get a new one, we can exchange the refresh token as [specified in the documentation](https://firebase.google.com/docs/reference/rest/auth#section-refresh-token).

```bash
curl 'https://securetoken.googleapis.com/v1/token?key=<censored>' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data 'grant_type=refresh_token&refresh_token=<refresh_token>' \
  --referer https://festify.us/
```

## Listen Request

<details>
  <summary>Metadata</summary>
  
  - Action: `q`
</details>

---

<!-- Location in source code: https://github.com/firebase/firebase-js-sdk/blob/cbfd14cfb27cda8a6de74be5d138ea9e6de09fe9/packages/database/src/core/PersistentConnection.ts#L274 -->

The listen request is used to query the database. It will return the current value and all future updates. All constants related to queries can be found in the [iOS SDK](https://github.com/firebase/firebase-ios-sdk/blob/7502fe3d09c23a90938bdd18ca0c2b64d711ec32/FirebaseDatabase/Sources/Constants/FConstants.m#L120-L131) again.

The body contains the following fields:
- path: The path to the data you want to query
- query: An object with custom queries you want to execute (optional)
- tag: Unique number used to identify the query (optional)
- hash: Hash of the query. Always empty.

```json
{
  "[p]ath": <path>,
  "[q]uery": <query>,
  "[t]ag": <tag>,
  "[h]ash": <hash>
}
```

The response will contain the current value and all future updates. The `data` field will contain the JSON as it's stored in the database or `null` if not found.

```json
{
  "[s]tatus": "ok",
  "[d]ata": <data>
}
```

### Example: Query party information

We can find all the information about a party with the following request:

```json
{
  "[p]ath": "/parties/-NeUUbtM3cqSazkSGvFb",
  "[h]ash": ""
}
```

The response contains all the information about the party (playback status, settings, etc.):

```json
{
  "[p]ath": "parties/-NeUUbtM3cqSazkSGvFb",
  "[d]ata": {
    "country": "NL",
    "created_at": 1694892987111,
    "created_by": "YGQejUpKxXYUe07fOc1P2s8NQ622",
    "name": "jukebox050's Party",
    "playback": {
      "last_change": 1695439571657,
      "last_position_ms": 137393,
      "playing": false
    },
    "settings": {
      "allow_anonymous_voters": true,
      "allow_explicit_tracks": true,
      "allow_multi_track_add": true,
      "tv_mode_text": "Add your songs on www.festify.us!"
    },
    "short_id": "885427"
  }
}
```


### Example: Query all parties

Querying a single party is cool, but can we dump all of them? Yes, we just have to change the path: 

```json
{
  "[p]ath": "/parties",
  "[h]ash": ""
}
```

This returns all the parties ever created:

```json
{
  "[p]ath": "parties",
  "[d]ata": {
    "-DE8BOdD2E0LDt6lBq6n": {
      "country": "DE",
      "created_at": 1513257439539,
      "created_by": "aYYftbv3wRWxZr8eowLx1KCJmPs1",
      "name": "Today's Party",
      "playback": {
        "last_change": 1513257439539,
        "last_position_ms": 0,
        "playing": false
      },
      "short_id": "526655"
    },
    ...
  }
}
```

We can use [jq](https://github.com/jqlang/jq) to analyze the data. 279.669 parties have been created since the launch of Festify in 2017. The top country is Germany, followed by the US and Brazil.

```bash
$ jq -r '.d.b.d[] | .country' dump.json | sort | uniq -c | sort -nr  
  89306 DE
  38237 US
  24120 BR
  19176 GB
  14711 NL
   7140 DK
   6251 CH
   5846 AU
   5376 CA
   4848 MX
   4709 BE
   4384 AT
   ...
```

Most of them seem to be used for private parties, which can be seen by some of the names (`Parents at my age: "gRoWiNg/eVoLvInG FaMiLy", Me: tell your cat I said pspsps` is my personal favorite). Some of them are even used for weddings, prayers and company parties. Out of the 119.719 unique names the majority (80.767) are only used once. Most people use the default name `Today's Party`, followed by some power users:
```bash
$ jq -r '.d.b.d[] | .name' fmt.json | sort | uniq -c | sort -nr
  32333 Today's Party
    488 wn8cleuqcwcm1excfj139ho1q's Party
    297 Spo's Party
    289 Grant Bowering's Party
    238 Tsurox's Party
    235 firefighter174's Party
```

37.592 parties have been created in the last year. Barely any of them are playing music, which makes sense since most of them are private parties.

### Example: Query tracks of a party

What if we want to know the tracks in the queue of a party? Easy, just change the path and that's it.

```json
{
  "[p]ath": "/tracks/-NeUUbtM3cqSazkSGvFb",
  "[h]ash": ""
}
```

This returns a list of all tracks in the queue (including the fallback tracks).
```json
{
  "p": "tracks/-NeUUbtM3cqSazkSGvFb",
  "d": {
    "spotify-4cOdK2wGLETKBW3PvgPWqT": {
      "added_at": 1697149626950,
      "is_fallback": true,
      "order": 2256639839,
      "reference": {
        "id": "4cOdK2wGLETKBW3PvgPWqT",
        "provider": "spotify"
      },
      "vote_count": 0
    },
    ...
  }
}
```

## Put Request

<details>
  <summary>Metadata</summary>
  
  - Action: `p`
</details>

---

Reading data is cool and all, but what if we want to change something? We can use the [put requests](https://github.com/firebase/firebase-js-sdk/blob/cbfd14cfb27cda8a6de74be5d138ea9e6de09fe9/packages/database/src/core/PersistentConnection.ts#L547-L554) to change the data in the database. Depending on the path, the permissions can be different. When in doubt, check the [database.rules.bolt](https://github.com/Festify/app/blob/develop/database.rules.bolt).

The message contains the path again and the data that should be stored. 
```json
{
  "[p]ath": <path>,
  "[d]ata": <json_data>
}
```

The response will just contain the status field: 

```json
{
  "[s]tatus": "ok",
  "[d]ata": null
}
```

### Example: Vote for song

The following request will add a new song to the database. 

```json
{
  "[p]ath": "/votes/<party_id>/spotify-<song_id>/<user_id>",
  "[d]ata": true
}
```

To withdraw your vote, you can send the same request with `d` set to `null`.

---

# Putting it all together

We learned how to authenticate, query and modify data in the database. These are all the building blocks we need to automate the process of voting for songs. I decided to write a Flutter app, to do exactly that and it worked like a charm!

<style>
video {
   max-width: 100%;
   max-height: 900px;
}

.video-container {
    display: flex;
    justify-content: space-around;
}

@media (max-width: 768px) {
    .video-container {
        flex-direction: column;
    }

    .video-container video {
        max-width: 100%;
        max-height: auto;
    }
}
</style>

<div class="video-container">
  <div>
  <b>Adding the song:</b><br/>
    <video controls>
      <source src="bot_vote_rick_astley.mp4" type="video/mp4">
      Your browser does not support the video tag.
    </video>
  </div>

  <div>
    <b>The result:</b><br/>
    <video controls>
      <source src="rick-astley.mp4" type="video/mp4">
      Your browser does not support the video tag.
    </video>
  </div>
</div>


# Mitigation

The only way to prevent automated voting is to disable anonymous voting. Festify even provides such a setting, but it has not yet been enabled. 

The reason is quite simple: You don't want to add too many unnecessary steps to the process of voting. Drunk people will most likely not want to enter their username and password just to add one song. The harder you make it to vote, the less people will vote. 

# Conclusion

This was a fun project and I learned a lot about Firebase. I hope you enjoyed reading this article and learned something new.

![Meme: I'm the DJ now](./im_the_dj_now.png)

<!-- 

Sources:
- https://github.com/urish/firebase-server
- https://github.com/firebase/firebase-js-sdk/blob/master/packages/database/src/core/ServerActions.ts
- https://github.com/darthwalsh/FireSocket/tree/master
- https://observablehq.com/@tomlarkworthy/firebase-server-prototype-1
  - Video: https://www.youtube.com/watch?v=rZby8_Cr9aE
- https://observablehq.com/@tomlarkworthy/rtdb-protocol

 -->
