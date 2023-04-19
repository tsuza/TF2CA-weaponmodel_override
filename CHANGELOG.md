## Release Notes

## [2.0.0]
Big change, thus big versioning change.
We've moved away from [Nosoop's custom attribute frameowrk](https://github.com/nosoop/SM-TFCustAttr) and we've switched over to [Nosoop's SMExt-TFEconDynamic](SMExt-TFEconDynamic), which utilizes a injection method to act just like actual TF2 attributes ( hence you can use TF2Attribute's functions to parse them ).

### Added

| Name                            | Class                       | Description                                                                                                                                           |
| ------------------------------- |-----------------------------| ------------------------------------------------------------------------------------------------------------------------------------------------------|
| `set weapon model`              | `set_weapon_model`          | It changes both the viewmodel and worldmodel of the weapon to the specified model.                                                                    |
| `set weapon viewmodel`          | `set_weapon_viewmodel`      | It changes the viewmodel of the weapon to the specified model. It overrides `set weapon model`.                                                       |
| `set weapon worldmodel`         | `set_weapon_worldmodel`     | It changes both the worldmodel of the weapon to the specified model. It overrides `set weapon model`.                                                 |
| `set viewmodel arms`            | `set_viewmodel_arms`        | It changes the arms model ( including arms ) to the specified model.                                                                                  |
| `set viewmodel bonemerged arms` | `set_viewmodel_animations`  | It changes the visible arms to the specified model. Useful if you want to set animations with `set viewmodel arms` but want to use a different model. |

### Fixed

### Removed

## [1.0.0]

### Added

### Fixed

### Removed
