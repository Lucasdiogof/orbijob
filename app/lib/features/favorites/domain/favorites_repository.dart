import '../../search/domain/entities/job_posting.dart';

/// Saved jobs of the signed-in user. Stores a snapshot of the posting, so a favourite stays readable
/// even if the job leaves the catalogue (or never was in it).
abstract class FavoritesRepository {
  Future<List<JobPosting>> list();
  Future<void> add(JobPosting job);
  Future<void> remove(JobPosting job);
}
