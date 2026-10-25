import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/fit_solver_service.dart';
import 'providers.dart';

class SolverInput {
  const SolverInput({
    required this.nominalSize,
    required this.fitType,
    required this.targetMinUm,
    required this.targetMaxUm,
  });

  final double nominalSize;
  final String fitType;
  final int targetMinUm;
  final int targetMaxUm;
}

final solverInputProvider = StateProvider<SolverInput?>((ref) => null);

final fitSolverServiceProvider = Provider<FitSolverService>((ref) {
  return FitSolverService(
    ref.watch(toleranceRepositoryProvider),
    ref.watch(knowledgeRepositoryProvider),
    ref.watch(databaseProvider),
  );
});

final solverResultsProvider = FutureProvider<List<FitCandidate>>((ref) async {
  final input = ref.watch(solverInputProvider);
  if (input == null) return const [];
  final ctx = ref.watch(standardContextProvider);
  return ref.watch(fitSolverServiceProvider).solve(
        nominalSize: input.nominalSize,
        fitType: input.fitType,
        targetMinUm: input.targetMinUm,
        targetMaxUm: input.targetMaxUm,
        ctx: ctx,
      );
});
