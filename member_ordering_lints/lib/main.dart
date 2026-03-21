import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:member_ordering_lints/src/member_ordering_rule.dart';

/// Top-level variable required by the analysis server plugin system.
final plugin = MemberOrderingPlugin();

class MemberOrderingPlugin extends Plugin {
  @override
  String get name => 'member_ordering_lints';

  @override
  void register(PluginRegistry registry) {
    // Registered as a lint rule — must be explicitly enabled in
    // analysis_options.yaml under `plugins: > diagnostics:`.
    // Use registerWarningRule() instead if you want it on by default.
    registry.registerWarningRule(MemberOrderingRule());
  }
}
