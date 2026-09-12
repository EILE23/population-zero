const { withProjectBuildGradle } = require('expo/config-plugins');

// SDK 57's version catalog override updates stdlib but the root classpath still
// inherits React Native's older compiler. Keep both on android.kotlinVersion.
module.exports = function withKotlinCompiler(config) {
  return withProjectBuildGradle(config, (mod) => {
    const original = "classpath('org.jetbrains.kotlin:kotlin-gradle-plugin')";
    const replacement = 'classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:${findProperty(\'android.kotlinVersion\')}")';
    if (mod.modResults.contents.includes(replacement)) return mod;
    if (!mod.modResults.contents.includes(original)) {
      throw new Error('Kotlin compiler configuration: unexpected root build.gradle; review the SDK template.');
    }
    mod.modResults.contents = mod.modResults.contents.replace(original, replacement);
    return mod;
  });
};
