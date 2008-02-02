/***************************************************************************
 *   Copyright (C) 2005-08 by the Quassel Project                          *
 *   devel@quassel-irc.org                                                 *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) version 3.                                           *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/

#ifndef _CORESESSION_H_
#define _CORESESSION_H_

#include <QString>
#include <QVariant>

#include "message.h"

class Identity;
class NetworkConnection;
class Network;
struct NetworkInfo;
class SignalProxy;

class QScriptEngine;

class CoreSession : public QObject {
  Q_OBJECT

public:
  CoreSession(UserId, bool restoreState, QObject *parent = 0);
  ~CoreSession();

  QList<BufferInfo> buffers() const;
  UserId user() const;
  Network *network(NetworkId) const;
  NetworkConnection *networkConnection(NetworkId) const;
  Identity *identity(IdentityId) const;

  QVariant sessionState();

  SignalProxy *signalProxy() const;

  void attachNetworkConnection(NetworkConnection *conn);

  //! Return necessary data for restoring the session after restarting the core
  void saveSessionState() const;
  void restoreSessionState();

public slots:
  void networkStateRequested();

  void addClient(QObject *socket);

  void connectToNetwork(QString, const QVariant &previousState = QVariant());
  void connectToNetwork(NetworkId, const QVariant &previousState = QVariant());
  void disconnectFromNetwork(NetworkId id);

  //void processSignal(ClientSignal, QVariant, QVariant, QVariant);
  void sendBacklog(BufferInfo, QVariant, QVariant);
  void msgFromClient(BufferInfo, QString message);

  //! Create an identity and propagate the changes to the clients.
  /** \param identity The identity to be created.
   */
  void createIdentity(const Identity &identity);

  //! Update an identity and propagate the changes to the clients.
  /** \param identity The identity to be updated.
   */
  void updateIdentity(const Identity &identity);

  //! Remove identity and propagate that fact to the clients.
  /** \param identity The identity to be removed.
   */
  void removeIdentity(IdentityId identity);

  //! Create a network and propagate the changes to the clients.
  /** \param info The network's settings.
   */
  void createNetwork(const NetworkInfo &info);

  //! Update a network and propagate the changes to the clients.
  /** \param info The updated network settings.
   */
  void updateNetwork(const NetworkInfo &info);

  //! Remove identity and propagate that fact to the clients.
  /** \param identity The identity to be removed.
   */
  void removeNetwork(NetworkId network);

signals:
  void initialized();

  //void msgFromGui(uint netid, QString buf, QString message);
  void displayMsg(Message message);
  void displayStatusMsg(QString, QString);

  //void connectToIrc(QString net);
  //void disconnectFromIrc(QString net);

  void backlogData(BufferInfo, QVariantList, bool done);

  void bufferInfoUpdated(BufferInfo);

  void scriptResult(QString result);

  //! Identity has been created.
  /** This signal is propagated to the clients to tell them that the given identity has been created.
   *  \param identity The new identity.
   */
  void identityCreated(const Identity &identity);

  //! Identity has been removed.
  /** This signal is propagated to the clients to inform them about the removal of the given identity.
   *  \param identity The identity that has been removed.
   */
  void identityRemoved(IdentityId identity);

  void networkCreated(NetworkId);
  void networkRemoved(NetworkId);

private slots:
  void recvStatusMsgFromServer(QString msg);
  void recvMessageFromServer(Message::Type, QString target, QString text, QString sender = "", quint8 flags = Message::None);
  void networkConnected(NetworkId networkid);
  void networkDisconnected(NetworkId networkid);

  //! Called when storage updated a BufferInfo.
  /** This emits bufferInfoUpdated() via SignalProxy, iff it's one of our buffers.
   *  \param user       The buffer's owner (not necessarily us)
   *  \param bufferInfo The updated BufferInfo
   */
  void updateBufferInfo(UserId user, const BufferInfo &bufferInfo);

  void scriptRequest(QString script);

private:
  void loadSettings();
  void initScriptEngine();

  UserId _user;

  SignalProxy *_signalProxy;
  QHash<NetworkId, NetworkConnection *> _connections;
  QHash<NetworkId, Network *> _networks;
  QHash<IdentityId, Identity *> _identities;

  QScriptEngine *scriptEngine;

};

#endif
