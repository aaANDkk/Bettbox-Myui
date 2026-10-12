import 'package:bett_box/common/common.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/profiles/scripts.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class ScriptOverride extends ConsumerWidget {
  const ScriptOverride({super.key});

  Future<void> _openScripts(BuildContext context) async {
    await showExtend(
      context,
      builder: (_, type) {
        return const ScriptsView();
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final scriptProps = ref.watch(scriptStateProvider);
    final validScriptIds = scriptProps.scripts.map((s) => s.id).toSet();
    final count = profiles
        .where(
          (p) =>
              p.useScriptOverride &&
              p.scriptId != null &&
              validScriptIds.contains(p.scriptId),
        )
        .length;

    return SizedBox(
      height: getWidgetHeight(1),
      child: CommonCard(
        info: Info(
          label: appLocalizations.script,
          iconData: FluentIcons.javascript_24_regular,
        ),
        onPressed: () => _openScripts(context),
        child: Container(
          padding: baseInfoEdgeInsets.copyWith(top: 0),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$count',
                  style: context.textTheme.bodyMedium?.toLight.adjustSize(1),
                ),
                const SizedBox(width: 4),
                Text(
                  ' Linked',
                  style: context.textTheme.bodyMedium?.toLight.adjustSize(0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
