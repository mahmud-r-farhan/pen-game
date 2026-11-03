// lib/ui/screens/private_room_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/auth/user_session.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/network/ws_client.dart';
import '../../models/arena_room.dart';

class PrivateRoomScreen extends StatefulWidget {
  const PrivateRoomScreen({super.key});

  @override
  State<PrivateRoomScreen> createState() => _PrivateRoomScreenState();
}

class _PrivateRoomScreenState extends State<PrivateRoomScreen> {
  final TextEditingController _codeController = TextEditingController();
  ArenaRoom _selectedRoom = ArenaRoom.rooms[0];
  String? _generatedCode;

  StreamSubscription<String>? _roomCodeSub;
  StreamSubscription<String>? _errorSub;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _roomCodeSub = KolomWsClient().onRoomCodeCreated.listen((code) {
      if (mounted) setState(() {
        _generatedCode = code;
        _isBusy = false;
      });
    });
    _errorSub = KolomWsClient().onError.listen((message) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    });
  }

  Future<void> _createRoom() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final profile = UserSession().profile;
      await KolomWsClient().connect(profile);
      KolomWsClient().createPrivateRoom(
        roomTypeId: _selectedRoom.id,
        penModel: profile.equippedPen,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the exact 6-digit room code.')),
      );
      return;
    }
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final profile = UserSession().profile;
      await KolomWsClient().connect(profile);
      KolomWsClient().joinPrivateRoom(roomCode: code, penModel: profile.equippedPen);
    } catch (error) {
      if (mounted) {
        setState(() => _isBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  void dispose() {
    if (_generatedCode != null && KolomWsClient().isConnected) {
      KolomWsClient().cancelPrivateRoom();
    }
    _roomCodeSub?.cancel();
    _errorSub?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.currentCode,
      builder: (context, code, child) {
        return Scaffold(
          backgroundColor: AppColors.bgObsidian,
          appBar: AppBar(
            backgroundColor: AppColors.bgSurfaceDark,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              children: [
                const Icon(Icons.vpn_key_rounded, color: AppColors.goldTiffinCoin, size: 22),
                const SizedBox(width: 8),
                Text(
                  AppLocale.tr('private_match'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Panel 1: Create Match
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.glassSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.add_circle_outline_rounded, color: AppColors.goldTiffinCoin),
                          SizedBox(width: 8),
                          Text(
                            'Host Custom Match',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Choose Arena & Table Stake:', style: TextStyle(color: AppColors.slateMuted, fontSize: 13)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<ArenaRoom>(
                        initialValue: _selectedRoom,
                        dropdownColor: AppColors.bgSurfaceDark,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.bgSurfaceDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.glassBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.glassBorder),
                          ),
                        ),
                        items: ArenaRoom.rooms.map((r) {
                          return DropdownMenuItem(
                            value: r,
                            child: Text(
                              '${r.nameEn} (${r.entryCoins} Coins)',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedRoom = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_generatedCode != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.emeraldTurn),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Room Code:', style: TextStyle(color: AppColors.slateMuted, fontSize: 12)),
                                  Text(
                                    _generatedCode!,
                                    style: const TextStyle(
                                      color: AppColors.goldTiffinCoin,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 28,
                                      letterSpacing: 4,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: _generatedCode!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Room code copied to clipboard!')),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, color: AppColors.emeraldTurn),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.goldTiffinCoin)),
                            SizedBox(width: 10),
                            Text('Waiting for friend to join with code...', style: TextStyle(color: AppColors.slateMuted, fontSize: 13)),
                          ],
                        ),
                      ] else
                        ElevatedButton(
                          onPressed: _isBusy ? null : _createRoom,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.goldTiffinCoin,
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Generate Room Code', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Panel 2: Join with Code
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.glassSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.login_rounded, color: AppColors.cyanSpin),
                          SizedBox(width: 8),
                          Text(
                            'Join with Room Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: 4,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter 6-digit code (e.g. 489210)',
                          hintStyle: const TextStyle(color: AppColors.slateMuted, fontSize: 14),
                          filled: true,
                          fillColor: AppColors.bgSurfaceDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.glassBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.glassBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: AppColors.cyanSpin),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isBusy ? null : _joinRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cyanSpin,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Join Match', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
