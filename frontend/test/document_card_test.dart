import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/document_item.dart';
import 'package:frontend/widgets/document_card.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  group('DocumentCard Widget QA Test Suite', () {
    testWidgets('1. [Render] Displays title, subtitle, and date accurately', (WidgetTester tester) async {
      final doc = DocumentItem(
        id: 'doc-1',
        title: 'Executive Employment Agreement.pdf',
        subtitle: '1.4 MB • Sent by HR',
        date: 'Oct 08, 2026',
        status: DocumentStatus.readyToSign,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          DocumentCard(
            item: doc,
            onTap: () {},
          ),
        ),
      );

      // Verify title, subtitle, and date are on screen
      expect(find.text('Executive Employment Agreement.pdf'), findsOneWidget);
      expect(find.text('1.4 MB • Sent by HR'), findsOneWidget);
      expect(find.text('•  Oct 08, 2026'), findsOneWidget);
    });

    testWidgets('2. [Status Badge] Shows "Ready to sign" badge for unsigned documents', (WidgetTester tester) async {
      final doc = DocumentItem(
        id: 'doc-2',
        title: 'NDA.pdf',
        subtitle: '500 KB',
        date: 'Oct 08, 2026',
        status: DocumentStatus.readyToSign,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          DocumentCard(
            item: doc,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Ready to sign'), findsOneWidget);
    });

    testWidgets('3. [Status Badge] Shows "Signed" badge and check icon for signed documents', (WidgetTester tester) async {
      final doc = DocumentItem(
        id: 'doc-3',
        title: 'Board_Resolution.pdf',
        subtitle: '2.1 MB',
        date: 'Oct 08, 2026',
        status: DocumentStatus.signed,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          DocumentCard(
            item: doc,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Signed'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('4. [Interaction] Triggers onTap callback when tapped', (WidgetTester tester) async {
      bool wasTapped = false;

      final doc = DocumentItem(
        id: 'doc-4',
        title: 'Vendor_Invoice.pdf',
        subtitle: '300 KB',
        date: 'Oct 08, 2026',
        status: DocumentStatus.readyToSign,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          DocumentCard(
            item: doc,
            onTap: () {
              wasTapped = true;
            },
          ),
        ),
      );

      // Tap on the card
      await tester.tap(find.byType(DocumentCard));
      await tester.pumpAndSettle();

      expect(wasTapped, isTrue);
    });
  });
}
