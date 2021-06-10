# p_malin-terminal-shaders

Silly Shadertoy Shaders I've hacked to work in Windows Terminal

Probably bad for your GPU - use at your own risk

## Usage

* Checkout the repository
* Set `experimental.pixelShaderPath` in your terminal config settings to the shader path
* Hear you GPU fan cry


## Example profile section in settings.json
```
    "profiles":
    {
      "defaults": {
        // Put settings here that you want to apply to all profiles.
        "experimental.pixelShaderPath": "C:\\gitrepo\\p_malin-terminal-shaders\\e1m1.hlsl"    
      },
```
