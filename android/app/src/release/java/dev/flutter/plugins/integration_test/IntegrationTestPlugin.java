package dev.flutter.plugins.integration_test;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * Release-only no-op for Flutter 3.44 generated plugin registration.
 *
 * The Flutter tool currently writes the dev-only integration_test plugin into
 * GeneratedPluginRegistrant.java while correctly excluding that package from
 * the release Gradle classpath. Keeping this tiny release source-set shim lets
 * production builds compile without bundling the integration-test runtime.
 * Debug/profile integration tests continue to use Flutter's real plugin.
 */
public final class IntegrationTestPlugin implements FlutterPlugin {
  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {}

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {}
}
