# Custom Weapon Models

Custom Attribute using Nosoop's [custom attributes framework](https://github.com/nosoop/SM-TFCustAttr). 
This plugin lets you set a custom weapon model to both worldmodel and viewmodel. The weapon model persists on dropped weapons. Note that this particular plugin to change weapon models doesn't have any lighting issues unlike some others ( arms turning red 'n such ).

**NOTE**: Shields aren't supported as of now. It's a bit weirder and I'm lazy. 

Tested it on Nosoop's [Custom Weapon X](https://github.com/nosoop/SM-TFCustomWeaponsX) and it works without any problems.

## How to apply the attribute

`"weaponmodel override"					"model path"`

Shove it inside tf_custom_attributes.txt if you want to replace a normal weapon's model ( or anything else that supports custom attributes ) or in the Custom Attribuets section inside a custom weapon's cfg if you use Custom Weapons X. 

Example of a model path: `models/necgaming/weapons/kunai/australium/c_shogun_kunai.mdl`

#

**HOWEVER,** the model won't show on non-bot clients. There is a missing property to enable it, but it's your job to find it ( in case you find it and want to put it in the plugin, I wrote a comment where you should put it ). It's not allowed to share it publicly.

This plugin uses Nosoop's [Ninja](https://github.com/nosoop/NinjaBuild-SMPlugin) template. Easy to organize everything and build releases. I'd recommend to check it out.

Please, this is the first version of this plugin. If you find any issues, make sure to open an issue to let me know!

Also I've got no clue how to properly format this.

https://media.discordapp.net/attachments/795689948908617760/803952503749607464/20210127122052_1.jpg

https://media.discordapp.net/attachments/642780993199013922/826102367756746813/unknown.png

https://media.discordapp.net/attachments/642780993199013922/826103949047365642/unknown.png

( I didn't make the Sentry Gun pistol model. Credits to the [original creator](https://gamebanana.com/skins/139638) for it. Amazing model btw )
