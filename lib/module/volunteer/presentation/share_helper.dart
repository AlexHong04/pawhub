import 'package:share_plus/share_plus.dart';

class ShareHelper {
  static Future<void> shareEvent({
    required Map<String, dynamic> event,
    required String formattedDate,
  }) async {
    final String title = event['title'] ?? 'Volunteer Event';
    final String location = event['address'] ?? 'Local Area';
    final int spots = event['spot_left'] ?? 0;

    // In a real app, this link would lead to your website or a deep link
    // final String appLink = "https://pawhub.app/events/${event['id']}";
    final String appLink = "https://pawhub.hongjin.site/event/${event['event_id']}";

    final String baseMessage =
        "🐾 Join me for a Volunteer Event: $title!\n\n"
        "📅 Date: $formattedDate\n"
        "📍 Location: $location\n\n"
        "There are only $spots spots left! Register here: $appLink\n\n"
        "#PawHub #Volunteer #AnimalRescue";

    await Share.share(
      baseMessage,
      subject: 'Interested in volunteering for $title?',
    );
  }
}