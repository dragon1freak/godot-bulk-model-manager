# Bulk Model Manager

> [!NOTE]
> This plugin was designed for Godot 4.4 and 4.5, for Godot 4.6+ I recommend using [Syvies](https://github.com/Syvies)' [Advanced Model Import](https://github.com/Syvies/godot-plugin-advanced-model-import) plugin

A Godot 4.4 plugin for speeding up workflows when using premade assets!

This plugin adds a tab to the top left dock of the inspector called `BMM`. From that tab, you can select materials you want to apply as external, extract materials on the models, or create inherited scenes, in bulk!

Currently supports `.fbx`, `.gltf`, and `.glb`

## Instructions

### Installation:

Drop the <code>bulk-model-manager</code> folder into your project's <code>addons</code> folder and enable the <code>Bulk Model Manager</code> plugin in your project settings.
<br>

### Usage

Open the `BMM` tab in the upper left dock, you'll see options to set materials, extract, materials, and create inherited scenes. You can do any of the following steps at once, any configured options will be applied when you hit `Apply`!

#### Set External Materials

The following steps are how to manually select materials that already exist in your project and should be applied to the selected models' `use_external` path. This step is always run if there are materials to set, whether it uses manually selected materials or materials extracted in the `Extract Materials` step.

1. Select the materials you wish to apply to your models by clicking the `Add` button. The material names **MUST** be unique and **match a material slot on the model**, otherwise it won't be applied as intended.
   - Select multiple models or directories using the Shift key or Ctrl key when clicking
2. Select any models or directories you wish to apply the materials to in the `FileSystem` dock. If you accidentally select other file types or the selected directory contains types other than FBX or GLTF/GLB, don't worry, they will be safely ignored!
   - Click the trash can button next to a selected material to remove it from the list
3. (Optional) Configure any other desired actions
4. Click `Apply`

#### Extract Materials

The following steps are how to extract all unique materials from the selected models. **ALL** materials that don't already exist in the target directory and don't match any materials selected manually will be extracted and saved to the target directory. They will also be used when setting the `use_external` path in the `Set External Materials` step of the process.

1. Check the `Extract Materials` checkbox, controls to configure a target path should appear.
2. Click `Set Path` and select the directory you wish to save the materials to.
   - Since this step also checks for existing materials, this can be useful if you've already exported the materials to the target directory
3. (Optional) Configure any other desired actions
4. Click `Apply`

#### Create Inherited Scenes

The following steps are how to create inherited scenes of the selected models and optionally create colliders for any meshes present. This can be useful when working with large amounts of props or environment assets that don't already have colliders.

1. Check the `Create Inherited Scenes` checkbox, controls to configure a target path, mirror the directories, and create colliders should appear.
2. Click `Set Path` and select the directory you wish to save the scenes to.
   - By default, if you have a directory selected a directory of the same name will be created in the target directory to contain the selected directory's created scenes. Uncheck the `Mirror Directory Structure` checkbox to disable this
3. (Optional) Check the `Create Colliders from Meshes` checkbox, controls to configure the created colliders should appear. The choices mirror the `Create Collision Shape` action found in the 3D editor when selecting a mesh.
4. (Optional) Configure any other desired actions
5. Click `Apply`

#### Troubleshooting

- One of my materials is being set for more than one slot
  - BSM uses the material name to match the material slot on the model, meaning the material names **must** be unique. If you have duplicate material names, the first one found in the list that matches will be used.
- The process seems successful, but the models/inherited scenes don't seem to be using the external material or the inherited scene is weird like meshes being out of place?
  - In some cases such as handling large amounts of models, the editor may fail to completely reimport/rescan all of the new models/materials/scenes. Try reloading the project.
- I'm getting an error in the console, something about `f.is_null()`?
  - As long as everything worked as intended, don't worry about it :)
