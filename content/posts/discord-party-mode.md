+++
title = "Reverse Engineering Discord's Party Mode"
date = "2022-05-15"

[taxonomies]
tags=["reverse engineering", "js"]
+++

If you haven't noticed yet, Discord added a 'Party Mode' because they are celebrating their 7th birthday. When a friend convinced me to enable it, I did the first few challenges, but quickly noticed that they are really repetitive.

So I did the only reasonable thing: **Automate it**. My friend used [puppeteer](https://github.com/puppeteer/puppeteer) to automate the tasks, but I decided to go through their source code and find the code that handles those achievements. 


<img src="https://user-images.githubusercontent.com/26800596/168480566-89c9c935-20e3-4745-ba34-0a5a8236489d.png" width="600" style="display: block; margin: auto">

# Where to start? 

When you've only got a UI, it's always hard to know where to start. There are a bunch of places to look. Since Discord uses [Electron](https://www.electronjs.org) we can either look through the files on disk or in the browser. 
We'd only go for the first option, if we know that the feature can only be accessed on the desktop application. An example for that would be the Discord overlay. But since the party mode also works in the browser, we can start there. 

After inspecting the HTML elements for the party mode, I couldn't see any references to any JavaScript functions. I also checked the networking tab, but there were no outgoing or incoming requests. Finally, I checked the console but there was also no output. 

Since all our attempts didn't bring us closer to figuring out how the party mode works, let's try something else. 
Discord has an asset folder with all their bundled code. The bundler compiles all the JavaScript files, minifies and sometimes even obfuscates them. Luckily, these are just minified, so we can right-click on the `assets` folder and search all the files in it. 

![assets-folder](https://user-images.githubusercontent.com/26800596/168480514-c7c59809-be12-413f-a27c-741eb020e20a.png)

We can now search for certain keywords and see what comes up. I tried keywords like `party`, `combo`, `confetti` and found the according file pretty quickly. 

# Reverse Engineering it

There are a bunch of references, that just contain mappings like these. They aren't really useful to us, because they are just mapping certain variables to their HTML identifiers. 
```javascript
440313: e=>{
	e.exports = {
		combo: "combo-2aK5O7",
		comboValue: "comboValue-1MDc9T",
		comboNameplate: "comboNameplate-2LHfRI",
		comboMultiplier: "comboMultiplier-YkNec8",
		comboSquare: "comboSquare-12yWYj",
		left: "left-2uQTLJ",
		right: "right-1c_YIP",
		confettiIcon: "confettiIcon-1nMd5V",
		tip: "tip-WcKlNf",
		messageComboScore: "messageComboScore-1cWPCc",
		comboScore: "comboScore-38MG6A"
	}
}
```

But there's also another file (`78a38cf0ea7963a0711a.js`), that handles the party mode logic. Just by looking at the strings and variable names, we can already guess what it's doing. For example, what do you think this code does? 
```js
!function(e) {
	e[e.ENABLE_POGGERMODE = 0] = "ENABLE_POGGERMODE";
	e[e.DISABLE_POGGERMODE = 1] = "DISABLE_POGGERMODE";
	e[e.PING_SOMEONE = 2] = "PING_SOMEONE";
	e[e.PING_ME = 3] = "PING_ME";
	e[e.COMBO_MULTI_LEVEL_1 = 4] = "COMBO_MULTI_LEVEL_1";
	e[e.COMBO_MULTI_LEVEL_2 = 5] = "COMBO_MULTI_LEVEL_2";
	e[e.COMBO_MULTI_LEVEL_3 = 6] = "COMBO_MULTI_LEVEL_3";
	e[e.COMBO_MULTI_LEVEL_4 = 7] = "COMBO_MULTI_LEVEL_4";
	e[e.TOTAL_SCORE_LEVEL_1 = 8] = "TOTAL_SCORE_LEVEL_1";
	e[e.TOTAL_SCORE_LEVEL_2 = 9] = "TOTAL_SCORE_LEVEL_2";
	e[e.TOTAL_SCORE_LEVEL_3 = 10] = "TOTAL_SCORE_LEVEL_3";
	e[e.TOTAL_SCORE_LEVEL_4 = 11] = "TOTAL_SCORE_LEVEL_4";
	e[e.TOTAL_SCORE_LEVEL_5 = 12] = "TOTAL_SCORE_LEVEL_5";
	e[e.VISITOR_100 = 13] = "VISITOR_100";
	e[e.CUSTOMIZE_CONFETTI = 14] = "CUSTOMIZE_CONFETTI";
	e[e.MORE = 15] = "MORE";
	e[e.COMBO_VALUE_LEVEL_1 = 16] = "COMBO_VALUE_LEVEL_1";
	e[e.COMBO_VALUE_LEVEL_2 = 17] = "COMBO_VALUE_LEVEL_2";
	e[e.COMBO_VALUE_LEVEL_3 = 18] = "COMBO_VALUE_LEVEL_3";
	e[e.COMBO_VALUE_LEVEL_4 = 19] = "COMBO_VALUE_LEVEL_4"
}(o || (t.PoggermodeAchievementId = o = {}));
```

If you know what achievements there are, you'll immediately recognize that this is the array that stores some data about them. And when scrolling down a little, you'll find exactly 19 blocks of code that all look somewhat like this:

```js
a[o.DISABLE_POGGERMODE] = {
	id: o.DISABLE_POGGERMODE,
	name: function() {
		return s.default.Messages.POGGERMODE_ACHIEVEMENT_DISABLE_POGGERMODE_NAME
	},
	description: function() {
		return s.default.Messages.POGGERMODE_ACHIEVEMENT_DISABLE_POGGERMODE_DESCRIPTION
	},
	rarity: i.UNCOMMON,
	hideDescriptionUntilUnlock: !1
},
```

There's even one legendary achievement that has an event handler. Can you guess which video they are opening? 
```js
 a[o.VISITOR_100] = {
	id: o.VISITOR_100,
	name: function() {
		return s.default.Messages.POGGERMODE_ACHIEVEMENT_VISITOR_100_NAME
	},
	description: function() {
		return s.default.Messages.POGGERMODE_ACHIEVEMENT_VISITOR_100_DESCRIPTION
	},
	rarity: i.LEGENDARY,
	hideDescriptionUntilUnlock: !0,
	onAction: function() {
		window.open("https://www.youtube.com/watch?v=dQw4w9WgXcQ", "_blank")
	}
},
```

So now we know where the achievement logic is located, can we figure out whether it's stored? I initially did some achievements by hand on the Desktop client, but when I opened the browser client, all of them were gone. Since there were also no outgoing or incoming requests when looking at the networking, we can be certain that the data is just stored locally. 

You could now either go through the file and search for references to storage APIs or look through `LocalStorage`. Since there's not that many options, the `PoggermodeAchievementStore` key might stand out. When you look at the stored value, you can clearly see the unlocked achievements. Nice!
![local-storage-value](https://user-images.githubusercontent.com/26800596/168480593-39fc7b50-e27c-4890-b273-58a93799b901.png)

# Patching it

Now that we know where the achievements are stored, we can easily modify it. I wanted to write a simple JavaScript program for that, but for whatever reason, `window.localStorage` wasn't defined. So instead of wasting more time to find a workaround, I decided to manually replace it. 

Since we already found the achievement array, we know that there's 19 of them. We can just write it out like this and replace the value. The `dateUnlocked` value is a epoch timestamp. You can create your own timestamp on [this website](https://www.epochconverter.com/). 
```json
{
    "_state": {
        "unlockedAchievements": {
            "0": {
                "achievementId": 0,
                "dateUnlocked": -19975457838000
            },
            "1": {
                "achievementId": 1,
                "dateUnlocked": -19975457838000
            },
            "2": {
                "achievementId": 2,
                "dateUnlocked": -19975457838000
            },
            // Skipped...
            "18": {
                "achievementId": 18,
                "dateUnlocked": -19975457838000
            },
            "19": {
                "achievementId": 19,
                "dateUnlocked": -19975457838000
            }
        }
    },
    "_version": 0
}
```

After reloading the client, we got all the achievements. Now I can brag to all of you about how cool I am. :)
![unlocked-achievements](https://user-images.githubusercontent.com/26800596/168480647-8cf956ea-e7b8-4973-b624-2b7c65a34980.png)

# What did we learn? 

This was only a small project, but we still learned quite a lot. We now know how we can start reversing websites or Electron applications. I'm using Firefox for all my personal browsing, but I decided to spin up Chrome because I know how good their DevTools are. So make sure to **use the right tool for the job**. 

---

I'm a big fan of [structured procrastination](https://www.urbandictionary.com/define.php?term=productive+procrastination) and [learning new things by starting a project](https://invidious.namazso.eu/watch?v=AMMOErxtahk). So if you catch yourself procrastinating or wasting time, try to turn it into a fun side project. 

**After all, it is never a waste of time to learn something new.**