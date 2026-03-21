library member_ordering_lints;

import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:member_ordering_lints/src/member_ordering_rule.dart';

PluginBase createPlugin() => _MemberOrderingPlugin();

class _MemberOrderingPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        MemberOrderingRule.fromConfigs(configs),
      ];
}
