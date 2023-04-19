<div align="center">
  <h1><code>TF2 Weaponmodel Override</code></h1>
  <p>
    <strong>A custom attribute that lets you change a weapon's worldmodel and viewmodel; the arms model and its animations.</strong>
  </p>
  <p style="margin-bottom: 0.5ex;">
    <img
        src="https://img.shields.io/github/downloads/Zabaniya001/TF2CA-weaponmodel_override/total"
    />
    <img
        src="https://img.shields.io/github/last-commit/Zabaniya001/TF2CA-weaponmodel_override"
    />
    <img
        src="https://img.shields.io/github/issues/Zabaniya001/TF2CA-weaponmodel_override"
    />
    <img
        src="https://img.shields.io/github/issues-closed/Zabaniya001/TF2CA-weaponmodel_override"
    />
    <img
        src="https://img.shields.io/github/repo-size/Zabaniya001/TF2CA-weaponmodel_override"
    />
    <img
        src="https://img.shields.io/github/workflow/status/Zabaniya001/TF2CA-weaponmodel_override/Compile%20and%20release"
    />
  </p>
</div>

![229254968-78f51103-9edd-46b9-8ccf-3e724dd5fb18 (1)](https://user-images.githubusercontent.com/73082112/232944588-90748b14-f8d5-4d0e-9f1a-09ad4a1c6cce.png)

*( I didn't make the Sentry Gun pistol model. Credits goes to the [original creator](https://gamebanana.com/skins/139638) for it. )*

## Information

### Attributes explanation

| Name                       | Class                       | Description                                                                                             |
| -------------------------- |-----------------------------| --------------------------------------------------------------------------------------------------------|
| `set weapon model`         | `set_weapon_model`          | It changes both the viewmodel and worldmodel of the weapon to the path you specify.                     |
| `set weapon viewmodel`     | `set_weapon_viewmodel`      | It changes the viewmodel of the weapon to the path you specify. It overrides `set weapon model`.        |
| `set weapon worldmodel`    | `set_weapon_worldmodel`     | It changes both the worldmodel of the weapon to the path you specify. It overrides `set weapon model`.  |
| `set viewmodel arms`       | `set_viewmodel_arms`        | It changes the arms model to the path you specify.                                                      |
| `set viewmodel animations` | `set_viewmodel_animations`  | It changes the animations that the arms use to the path you specify.                                    |

---

### How to apply
You can apply these attributes via config with whatever plugin you're using ( if there is enough demand I can create one ).

Since this attribute acts like a TF2 attribute, you can utilize [TF2Attribute][Nosoop's TF2 Attribute fork]'s [TF2Attrib_SetFromStringValue](https://github.com/nosoop/tf2attributes/blob/af679918a88464cc23ad86ad737db837c89473bc/scripting/include/tf2attributes.inc#LL45C13-L45C41) or any other native to set it. You can also retrieve the value with the given API. 

**Example:** `"set weapon model" "models/necgaming/weapons/kunai/australium/c_shogun_kunai.mdl"`

---

### Not supported ( for now )

 - Shields don't work properly.

## Installation

### Requirements

- [Nosoop's Econ Dynamic] ( It injects custom attributes to act like real ones )
- [TF2 Utils]
- [Nosoop's TF2 Attribute fork]


### Supported

- [CWX / Custom Weapons X]


[Nosoop's Econ Dynamic]: [https://github.com/nosoop/SMExt-TFEconDynamic]
[TF2 Utils]: [https://github.com/nosoop/SM-TFUtils]
[Nosoop's TF2 Attribute fork]: [https://github.com/nosoop/tf2attributes]
[CWX / Custom Weapons X]: [https://github.com/nosoop/SM-TFCustomWeaponsX]