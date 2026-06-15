import 'package:flutter/material.dart';

import '../models/rental_models.dart';
import '../services/booking_repository.dart';
import '../services/profile_repository.dart';
import '../services/support_repository.dart';
import '../theme/app_palette.dart';
import '../widgets/rental_widgets.dart';

class SupportInboxScreen extends StatelessWidget {
  const SupportInboxScreen({
    super.key,
    required this.supportRepository,
    required this.bookingRepository,
    required this.currentProfile,
    required this.currentUserId,
    required this.isAdmin,
  });

  final SupportRepository supportRepository;
  final BookingRepository bookingRepository;
  final UserProfile currentProfile;
  final String currentUserId;
  final bool isAdmin;

  Future<void> _openGeneralSupport(BuildContext context) async {
    final conversation = await supportRepository.getOrCreateGeneralConversation(
      customerProfile: currentProfile,
    );
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportConversationScreen(
          supportRepository: supportRepository,
          bookingRepository: bookingRepository,
          currentProfile: currentProfile,
          currentUserId: currentUserId,
          conversation: conversation,
        ),
      ),
    );
  }

  Future<void> _openConversation(
    BuildContext context,
    SupportConversation conversation,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportConversationScreen(
          supportRepository: supportRepository,
          bookingRepository: bookingRepository,
          currentProfile: currentProfile,
          currentUserId: currentUserId,
          conversation: conversation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(isAdmin ? 'Support inbox' : 'Customer support'),
      ),
      body: StreamBuilder<List<SupportConversation>>(
        stream: supportRepository.watchConversations(
          userId: currentUserId,
          isAdmin: isAdmin,
        ),
        builder: (context, snapshot) {
          final conversations = snapshot.data ?? const <SupportConversation>[];
          final bookingConversations =
              conversations.where((conversation) => conversation.isBookingConversation).length;
          final unreadCount = conversations
              .where(
                (conversation) =>
                    conversation.lastMessage.trim().isNotEmpty &&
                    conversation.lastMessageSenderId.isNotEmpty &&
                    conversation.lastMessageSenderId != currentUserId,
              )
              .length;

          if (snapshot.connectionState == ConnectionState.waiting &&
              conversations.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                AppLoadingCard(height: 128),
                SizedBox(height: 14),
                AppLoadingCard(height: 108),
                SizedBox(height: 14),
                AppLoadingCard(height: 108),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (isAdmin) ...[
                _SupportAdminOverviewCard(
                  totalConversations: conversations.length,
                  bookingConversations: bookingConversations,
                  unreadConversations: unreadCount,
                ),
                const SizedBox(height: 18),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.brandDeep, colors.brandMid],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need help with your ride?',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a chat with admin for booking questions, payment help, or pickup issues.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.88),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _openGeneralSupport(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: colors.brandDeep,
                        ),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('Start general support'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              if (conversations.isEmpty)
                AppEmptyState(
                  icon: isAdmin
                      ? Icons.support_agent_rounded
                      : Icons.chat_bubble_outline_rounded,
                  title: 'No support chats yet',
                  message: isAdmin
                      ? 'Customer conversations will appear here as soon as someone sends a message.'
                      : 'Open a general support chat or use the support button on any booking card.',
                  actionLabel: isAdmin ? null : 'Start support chat',
                  onAction: isAdmin ? null : () => _openGeneralSupport(context),
                )
              else ...[
                AppSectionHeader(
                  title: isAdmin ? 'Recent conversations' : 'Your conversations',
                  subtitle: isAdmin
                      ? 'Reply quickly when customers need help.'
                      : 'Open any chat to continue where you left off.',
                ),
                const SizedBox(height: 14),
                ...conversations.map(
                  (conversation) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                  child: _SupportConversationCard(
                      conversation: conversation,
                      isAdminView: isAdmin,
                      currentUserId: currentUserId,
                      onTap: () => _openConversation(context, conversation),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class SupportConversationScreen extends StatefulWidget {
  const SupportConversationScreen({
    super.key,
    required this.supportRepository,
    required this.bookingRepository,
    required this.currentProfile,
    required this.currentUserId,
    required this.conversation,
  });

  final SupportRepository supportRepository;
  final BookingRepository bookingRepository;
  final UserProfile currentProfile;
  final String currentUserId;
  final SupportConversation conversation;

  @override
  State<SupportConversationScreen> createState() => _SupportConversationScreenState();
}

class _SupportConversationScreenState extends State<SupportConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }

    setState(() => _sending = true);
    try {
      await widget.supportRepository.sendMessage(
        conversation: widget.conversation,
        senderProfile: widget.currentProfile,
        text: text,
      );
      _messageController.clear();
      if (_scrollController.hasClients) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      showAppBanner(
        context,
        message: error.toString().trim().isEmpty
            ? 'Could not send your message right now.'
            : error.toString().trim(),
        tone: AppBannerTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _showCustomerDetailsSheet() async {
    final conversation = widget.conversation;
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final bookingLabel = conversation.bookingVehicleName?.trim().isNotEmpty == true
        ? conversation.bookingVehicleName!.trim()
        : 'Booking support';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    ProfileAvatar(
                      imageUrl: conversation.customerPhotoUrl,
                      initials: conversation.customerName.isEmpty
                          ? 'C'
                          : conversation.customerName.substring(0, 1).toUpperCase(),
                      radius: 28,
                      backgroundColor: colors.brandTintStrong,
                      textColor: colors.brandDeep,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conversation.customerName,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            conversation.customerEmail.isEmpty
                                ? 'No email added'
                                : conversation.customerEmail,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SupportDetailCard(
                  children: [
                    _SupportDetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Customer',
                      value: conversation.customerName,
                    ),
                    const SizedBox(height: 12),
                    _SupportDetailRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: conversation.customerEmail.isEmpty
                          ? 'Not available'
                          : conversation.customerEmail,
                    ),
                    const SizedBox(height: 12),
                    _SupportDetailRow(
                      icon: Icons.phone_iphone_rounded,
                      label: 'Phone',
                      value: conversation.customerPhoneNumber.isEmpty
                          ? 'Not available'
                          : conversation.customerPhoneNumber,
                    ),
                    const SizedBox(height: 12),
                    _SupportDetailRow(
                      icon: Icons.support_agent_rounded,
                      label: 'Support type',
                      value: conversation.isBookingConversation
                          ? 'Booking support'
                          : 'General support',
                    ),
                    if (conversation.isBookingConversation) ...[
                      const SizedBox(height: 12),
                      _SupportDetailRow(
                        icon: Icons.directions_car_filled_rounded,
                        label: 'Vehicle',
                        value: bookingLabel,
                      ),
                      if ((conversation.bookingPickupHub ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SupportDetailRow(
                          icon: Icons.storefront_outlined,
                          label: 'Pickup hub',
                          value: conversation.bookingPickupHub!.trim(),
                        ),
                      ],
                      if ((conversation.bookingScheduleLabel ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SupportDetailRow(
                          icon: Icons.schedule_rounded,
                          label: 'Schedule',
                          value: conversation.bookingScheduleLabel!.trim(),
                        ),
                      ],
                      if ((conversation.bookingStatusLabel ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _SupportDetailRow(
                          icon: Icons.assignment_turned_in_outlined,
                          label: 'Booking status',
                          value: conversation.bookingStatusLabel!.trim(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _SupportDetailRow(
                        icon: Icons.receipt_long_outlined,
                        label: 'Booking reference',
                        value: conversation.bookingId ?? 'Not available',
                      ),
                    ],
                    const SizedBox(height: 12),
                    _SupportDetailRow(
                      icon: Icons.badge_outlined,
                      label: 'Customer user ID',
                      value: conversation.customerUserId,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openHeaderAction() async {
    final conversation = widget.conversation;
    if (widget.currentProfile.isAdmin &&
        conversation.isBookingConversation &&
        (conversation.bookingId ?? '').trim().isNotEmpty) {
      final booking = await widget.bookingRepository.getBookingById(
        conversation.bookingId!.trim(),
      );
      if (!mounted) {
        return;
      }
      if (booking == null) {
        showAppBanner(
          context,
          message: 'This booking could not be found.',
          tone: AppBannerTone.error,
        );
        return;
      }
      await _showBookingDetailsSheet(booking);
      return;
    }
    await _showCustomerDetailsSheet();
  }

  Future<void> _showBookingDetailsSheet(BookingRecord booking) async {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final accountName = booking.account?.displayName.trim().isNotEmpty == true
        ? booking.account!.displayName
        : widget.conversation.customerName;
    final accountEmail = booking.account?.email.trim().isNotEmpty == true
        ? booking.account!.email
        : widget.conversation.customerEmail;
    final accountPhone = booking.account?.phoneNumber.trim().isNotEmpty == true
        ? booking.account!.phoneNumber
        : widget.conversation.customerPhoneNumber;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _BookingVehicleImage(
                    imageUrl: booking.vehicle.imageUrl,
                    vehicleType: booking.vehicle.type,
                    height: 170,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.vehicle.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            booking.vehicle.type.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _SupportStatusChip(label: booking.status.label),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SupportInfoPill(
                      icon: Icons.payments_outlined,
                      label: 'Total',
                      value: '\$${booking.totalPrice.toStringAsFixed(booking.totalPrice == booking.totalPrice.roundToDouble() ? 0 : 1)}',
                    ),
                    _SupportInfoPill(
                      icon: Icons.storefront_outlined,
                      label: 'Pickup',
                      value: booking.pickupHub,
                    ),
                    _SupportInfoPill(
                      icon: Icons.schedule_rounded,
                      label: 'Schedule',
                      value:
                          '${_formatSupportDate(booking.startDate)} • ${_formatSupportTime(booking.startDate)}',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SupportDetailCard(
                  children: [
                    _SupportDetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Customer',
                      value: accountName,
                    ),
                    const SizedBox(height: 12),
                    _SupportDetailRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: accountEmail.isEmpty ? 'Not available' : accountEmail,
                    ),
                    const SizedBox(height: 12),
                    _SupportDetailRow(
                      icon: Icons.phone_iphone_rounded,
                      label: 'Phone',
                      value: accountPhone.isEmpty ? 'Not available' : accountPhone,
                    ),
                    const SizedBox(height: 12),
                    _SupportDetailRow(
                      icon: Icons.timelapse_rounded,
                      label: 'Duration',
                      value: '${booking.quantity} ${booking.unit.label.toLowerCase()} rental',
                    ),
                    const SizedBox(height: 12),
                    _SupportDetailRow(
                      icon: Icons.flag_outlined,
                      label: 'Return',
                      value:
                          '${_formatSupportDate(booking.endDate)} • ${_formatSupportTime(booking.endDate)}',
                    ),
                    const SizedBox(height: 12),
                    _SupportDetailRow(
                      icon: Icons.receipt_long_outlined,
                      label: 'Booking reference',
                      value: booking.id,
                    ),
                    if ((booking.deliveryNotes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _SupportDetailRow(
                        icon: Icons.notes_rounded,
                        label: 'Notes',
                        value: booking.deliveryNotes!.trim(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final conversation = widget.conversation;
    final title = conversation.isBookingConversation
        ? (conversation.bookingVehicleName?.trim().isNotEmpty == true
            ? conversation.bookingVehicleName!.trim()
            : conversation.subject)
        : conversation.subject;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        actions: [
          if (widget.currentProfile.isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _openHeaderAction,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: ProfileAvatar(
                    imageUrl: conversation.customerPhotoUrl,
                    initials: conversation.customerName.isEmpty
                        ? 'C'
                        : conversation.customerName.substring(0, 1).toUpperCase(),
                    radius: 18,
                    backgroundColor: colors.brandTintStrong,
                    textColor: colors.brandDeep,
                  ),
                ),
              ),
            ),
        ],
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              conversation.isBookingConversation ? 'Booking support' : 'General support',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (conversation.isBookingConversation)
              _SupportBookingSummaryCard(
                conversation: conversation,
                isAdminView: widget.currentProfile.isAdmin,
              ),
            if (!conversation.isBookingConversation)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.borderSoft),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? colors.surfaceMuted
                            : colors.brandTintStrong,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.brightness == Brightness.dark
                              ? colors.brand.withValues(alpha: 0.22)
                              : colors.brandDeep.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Icon(
                        Icons.support_agent_rounded,
                        color: theme.brightness == Brightness.dark
                            ? colors.brand
                            : colors.brandDeep,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Keep the conversation here so support replies stay in one place.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: StreamBuilder<List<SupportMessage>>(
                stream: widget.supportRepository.watchMessages(conversation.id),
                builder: (context, snapshot) {
                  final messages = snapshot.data ?? const <SupportMessage>[];

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      messages.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                      children: const [
                        AppLoadingCard(height: 94),
                        SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 220,
                            child: AppLoadingCard(height: 86),
                          ),
                        ),
                        SizedBox(height: 12),
                        SizedBox(
                          width: 250,
                          child: AppLoadingCard(height: 96),
                        ),
                      ],
                    );
                  }

                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: const AppEmptyState(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Start the conversation',
                          message:
                              'Send your first message and admin can reply here.',
                        ),
                      ),
                    );
                  }

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent,
                      );
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMine = message.senderUserId == widget.currentUserId;
                      final previous = index == 0 ? null : messages[index - 1];
                      final showDateDivider = previous == null ||
                          previous.createdAt.year != message.createdAt.year ||
                          previous.createdAt.month != message.createdAt.month ||
                          previous.createdAt.day != message.createdAt.day;
                      return Column(
                        children: [
                          if (showDateDivider)
                            _SupportDateDivider(date: message.createdAt),
                          _SupportMessageBubble(
                            message: message,
                            isMine: isMine,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: colors.background,
                border: Border(
                  top: BorderSide(color: colors.borderSoft),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Write a message',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _sending ? null : _sendMessage,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportConversationCard extends StatelessWidget {
  const _SupportConversationCard({
    required this.conversation,
    required this.isAdminView,
    required this.currentUserId,
    required this.onTap,
  });

  final SupportConversation conversation;
  final bool isAdminView;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final subtitle = conversation.lastMessage.trim().isEmpty
        ? 'No messages yet'
        : conversation.lastMessage.trim();
    final bookingLabel = conversation.bookingVehicleName?.trim() ?? '';
    final accentColor = conversation.isBookingConversation
        ? colors.brand
        : colors.brandSoft;
    final awaitingReply = conversation.lastMessage.isNotEmpty &&
        conversation.lastMessageSenderId.isNotEmpty &&
        conversation.lastMessageSenderId != currentUserId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.borderSoft),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3,
                height: 82,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              ProfileAvatar(
                imageUrl: conversation.customerPhotoUrl,
                initials: conversation.customerName.isEmpty
                    ? 'C'
                    : conversation.customerName.substring(0, 1).toUpperCase(),
                radius: 24,
                backgroundColor: colors.brandTintStrong,
                textColor: colors.brandDeep,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isAdminView ? conversation.customerName : conversation.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatSupportTime(conversation.lastMessageAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (awaitingReply) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors.brand,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colors.brand.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SupportTag(
                          label: conversation.isBookingConversation
                              ? 'Booking support'
                              : 'General support',
                          filled: conversation.isBookingConversation,
                        ),
                        if (isAdminView &&
                            conversation.bookingVehicleName?.trim().isNotEmpty == true)
                          _SupportTag(
                            label: conversation.bookingVehicleName!.trim(),
                          ),
                        if (awaitingReply)
                          _SupportTag(
                            label: isAdminView ? 'Needs reply' : 'Admin replied',
                            filled: true,
                          ),
                        if (!isAdminView &&
                            conversation.lastMessage.trim().isNotEmpty)
                          const _SupportTag(
                            label: 'Latest update',
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.surfaceSoft,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.borderSoft),
                      ),
                      child: Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (bookingLabel.isNotEmpty && !isAdminView) ...[
                      const SizedBox(height: 10),
                      Text(
                        bookingLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportAdminOverviewCard extends StatelessWidget {
  const _SupportAdminOverviewCard({
    required this.totalConversations,
    required this.bookingConversations,
    required this.unreadConversations,
  });

  final int totalConversations;
  final int bookingConversations;
  final int unreadConversations;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.brandDeep, colors.brandMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Support workspace',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review new customer questions, open booking-linked issues, and reply from one place.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SupportOverviewStat(
                  label: 'Total chats',
                  value: totalConversations.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SupportOverviewStat(
                  label: 'Booking issues',
                  value: bookingConversations.toString(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SupportOverviewStat(
                  label: 'Unread',
                  value: unreadConversations.toString(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportOverviewStat extends StatelessWidget {
  const _SupportOverviewStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportBookingSummaryCard extends StatelessWidget {
  const _SupportBookingSummaryCard({
    required this.conversation,
    required this.isAdminView,
  });

  final SupportConversation conversation;
  final bool isAdminView;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);
    final statusLabel = (conversation.bookingStatusLabel ?? '').trim();
    final pickupHub = (conversation.bookingPickupHub ?? '').trim();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? colors.surfaceMuted
                      : colors.brandTintStrong,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? colors.brand.withValues(alpha: 0.22)
                        : colors.brandDeep.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: theme.brightness == Brightness.dark
                      ? colors.brand
                      : colors.brandDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAdminView ? 'Booking support' : 'Need help with this booking?',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAdminView
                          ? 'Review the issue here and tap the avatar for full booking details.'
                          : 'Chat here if something is wrong with this booking or you need admin help.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isAdminView)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SupportBookingInfoChip(
                  icon: Icons.support_agent_rounded,
                  label: 'Type',
                  value: 'Booking support',
                ),
                if (statusLabel.isNotEmpty)
                  _SupportBookingInfoChip(
                    icon: Icons.flag_outlined,
                    label: 'Status',
                    value: statusLabel,
                  ),
                if (pickupHub.isNotEmpty)
                  _SupportBookingInfoChip(
                    icon: Icons.storefront_outlined,
                    label: 'Hub',
                    value: pickupHub,
                  ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SupportTag(
                  label: 'Booking support',
                  filled: true,
                ),
                if (pickupHub.isNotEmpty)
                  _SupportTag(label: pickupHub),
                if (statusLabel.isNotEmpty)
                  _SupportTag(label: statusLabel),
              ],
            ),
        ],
      ),
    );
  }
}

class _SupportBookingInfoChip extends StatelessWidget {
  const _SupportBookingInfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.brand),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportTag extends StatelessWidget {
  const _SupportTag({
    required this.label,
    this.filled = false,
  });

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? colors.brandTintStrong : colors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: filled ? colors.brand.withValues(alpha: 0.18) : colors.borderSoft,
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: filled
              ? (theme.brightness == Brightness.dark ? colors.brand : colors.brandDeep)
              : colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SupportMessageBubble extends StatelessWidget {
  const _SupportMessageBubble({
    required this.message,
    required this.isMine,
  });

  final SupportMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);
    final bubbleColor = isMine ? colors.brandDeep : colors.surfaceSoft;
    final textColor = isMine ? Colors.white : colors.textPrimary;
    final metaColor = isMine
        ? Colors.white.withValues(alpha: 0.82)
        : colors.textSecondary;
    final senderLabel = message.isAdminSender ? 'Admin' : message.senderName;
    final senderBadgeBackground = theme.brightness == Brightness.dark
        ? colors.brand.withValues(alpha: 0.18)
        : colors.brandTintStrong;
    final senderBadgeBorder = theme.brightness == Brightness.dark
        ? colors.brand.withValues(alpha: 0.34)
        : colors.brand.withValues(alpha: 0.18);
    final senderBadgeText = theme.brightness == Brightness.dark
        ? colors.textPrimary
        : colors.brandDeep;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMine ? 20 : 6),
              bottomRight: Radius.circular(isMine ? 6 : 20),
            ),
            border: isMine ? null : Border.all(color: colors.borderSoft),
            boxShadow: isMine
                ? [
                    BoxShadow(
                      color: colors.brand.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: senderBadgeBackground,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: senderBadgeBorder),
                  ),
                  child: Text(
                    senderLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: senderBadgeText,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isMine
                    ? _formatSupportTime(message.createdAt)
                    : 'Sent ${_formatSupportTime(message.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: metaColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportDateDivider extends StatelessWidget {
  const _SupportDateDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: colors.borderSoft,
              thickness: 1,
              height: 1,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.surfaceSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.borderSoft),
            ),
            child: Text(
              _formatSupportDate(date),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: colors.borderSoft,
              thickness: 1,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatSupportTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _formatSupportDate(DateTime value) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[value.month - 1];
  return '$month ${value.day}, ${value.year}';
}

class _BookingVehicleImage extends StatelessWidget {
  const _BookingVehicleImage({
    required this.imageUrl,
    required this.vehicleType,
    required this.height,
  });

  final String imageUrl;
  final VehicleType vehicleType;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final trimmed = imageUrl.trim();

    if (trimmed.isEmpty) {
      return Container(
        height: height,
        color: colors.brandTintStrong,
        child: Icon(
          vehicleType.icon,
          size: 54,
          color: colors.brand,
        ),
      );
    }

    if (trimmed.startsWith('assets/')) {
      return Image.asset(
        trimmed,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      trimmed,
      width: double.infinity,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return Container(
          height: height,
          color: colors.brandTintStrong,
          child: Icon(
            vehicleType.icon,
            size: 54,
            color: colors.brand,
          ),
        );
      },
    );
  }
}

class _SupportStatusChip extends StatelessWidget {
  const _SupportStatusChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SupportInfoPill extends StatelessWidget {
  const _SupportInfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.textSecondary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportDetailCard extends StatelessWidget {
  const _SupportDetailCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SupportDetailRow extends StatelessWidget {
  const _SupportDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: colors.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
