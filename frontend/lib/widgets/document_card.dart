import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/document_item.dart';

/// DocumentCard renders a single document item in the list.
/// It displays:
/// 1. A document icon on the left
/// 2. Status badge, date, title, and subtitle in the middle
/// 3. A chevron navigation arrow on the right
class DocumentCard extends StatelessWidget {
  // The document data model passed from the parent list
  final DocumentItem item;

  // Callback function triggered when the user taps anywhere on this card.
  // Using a callback lets the parent screen decide where to navigate.
  final VoidCallback onTap;

  // Callback function triggered when user taps the direct Share button
  final VoidCallback? onShare;

  const DocumentCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    // Check status once to decide which colors and icons to show
    final bool isSigned = item.status == DocumentStatus.signed;

    return Container(
      // Margin creates vertical breathing room between cards in the list
      margin: const EdgeInsets.only(bottom: 12),
      
      // BoxDecoration creates the visual "card" look: adaptive background, subtle border, rounded corners
      decoration: BoxDecoration(
        color: AppTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context)),
        // Soft elevation shadow to make the card feel slightly raised above the background
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppTheme.isDark(context) ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      
      // Material widget is required for InkWell touch ripple to render properly.
      // We set color to transparent so it doesn't hide our Container's decoration.
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // Match the container's border radius so the ripple doesn't bleed outside the corners
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            // Inner padding keeps content comfortably away from the card edges
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // -------------------------------------------------------------
                // SECTION 1: LEFT ICON CONTAINER
                // -------------------------------------------------------------
                // A fixed 50x50 box holding the document or check icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryBg(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    // Show a checkmark if signed, otherwise a document icon
                    isSigned ? Icons.check_circle_outline : Icons.description_outlined,
                    color: AppTheme.primaryBlue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),

                // -------------------------------------------------------------
                // SECTION 2: MIDDLE DETAILS (BADGE, TITLE, SUBTITLE)
                // -------------------------------------------------------------
                // Expanded tells Flutter: "Take up whatever width remains between 
                // the left icon and the right arrow, preventing horizontal overflow."
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sub-row: Status Pill Badge + Date
                      Row(
                        children: [
                          // The pill container for status
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSigned
                                  ? AppTheme.badgeSignedBgDynamic(context)
                                  : AppTheme.badgeReadyBgDynamic(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isSigned) ...[
                                  // Small colored dot for "Ready to sign"
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: AppTheme.badgeReadyTextDynamic(context),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                ] else ...[
                                  // Small check icon for "Signed"
                                  Icon(
                                    Icons.check,
                                    size: 12,
                                    color: AppTheme.badgeSignedTextDynamic(context),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  isSigned ? 'Signed' : 'Ready to sign',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isSigned
                                        ? AppTheme.badgeSignedTextDynamic(context)
                                        : AppTheme.badgeReadyTextDynamic(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Document creation/modification date
                          Text(
                            '•  ${item.date}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Document Title
                      Text(
                        item.title,
                        maxLines: 1,
                        // TextOverflow.ellipsis converts long titles like "Non-Disclosure..." 
                        // so text never overflows past the screen edge
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Document Subtitle (e.g. "2 signers • Requires 1 field")
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // -------------------------------------------------------------
                // SECTION 3: RIGHT ACTIONS (SHARE BUTTON & CHEVRON)
                // -------------------------------------------------------------
                if (isSigned && onShare != null) ...[
                  IconButton(
                    icon: const Icon(
                      Icons.share_outlined,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                    tooltip: 'Share Document',
                    splashRadius: 20,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    onPressed: onShare,
                  ),
                  const SizedBox(width: 4),
                ],

                // Visual cue indicating to the user that tapping will open this item
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.textSecondary(context).withValues(alpha: 0.6),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}