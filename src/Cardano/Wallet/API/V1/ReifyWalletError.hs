{-# LANGUAGE ScopedTypeVariables        #-}
{-# LANGUAGE RankNTypes                 #-}
{-# LANGUAGE TypeApplications    #-}

module Cardano.Wallet.API.V1.ReifyWalletError (
    translateWalletLayerErrors
    ) where

import qualified Data.Text as T

import           Formatting (build, sformat)
import           Universum

import           Pos.Core (decodeTextAddress)

import qualified Cardano.Wallet.API.V1.Types as V1
import           Cardano.Wallet.API.V1.Types (V1 (..))
import qualified Cardano.Wallet.Kernel.Accounts as Kernel
import qualified Cardano.Wallet.Kernel.Addresses as Kernel
import           Cardano.Wallet.Kernel.CoinSelection.Generic (CoinSelHardErr (..))
import           Cardano.Wallet.Kernel.DB.AcidState (NewPendingError (..),
    NewForeignError (..))
import qualified Cardano.Wallet.Kernel.DB.HdWallet as HD
import qualified Cardano.Wallet.Kernel.DB.HdWallet.Create as HD
import qualified Cardano.Wallet.Kernel.Transactions as Kernel
import qualified Cardano.Wallet.Kernel.Wallets as Kernel
import           Cardano.Wallet.WalletLayer
import           Cardano.Wallet.WalletLayer.Kernel.Conv (toRootId)

-- | Translates all kernel exceptions to the WalletError sum type and returns
--   Nothing for non-kernel exceptions.
translateWalletLayerErrors :: SomeException -> Maybe V1.WalletError
translateWalletLayerErrors ex = do
       (    try' @CreateAddressError createAddressError
        <|> try' @ValidateAddressError validateAddressError

        <|> try' @CreateAccountError createAccountError
        <|> try' @GetAccountError getAccountError
        <|> try' @UpdateAccountError updateAccountError
        <|> try' @DeleteAccountError deleteAccountError
        <|> try' @GetAccountsError getAccountsError

        <|> try' @CreateWalletError createWalletError
        <|> try' @GetWalletError getWalletError
        <|> try' @UpdateWalletError updateWalletError
        <|> try' @UpdateWalletPasswordError updateWalletPasswordError
        <|> try' @DeleteWalletError deleteWalletError
        <|> try' @ImportWalletError importWalletError

        <|> try' @GetUtxosError getUtxosError
        <|> try' @GetTxError getTxError
        <|> try' @EstimateFeesError estimateFeesError

        <|> try' @RedeemAdaError redeemAdaError
        <|> try' @NewPaymentError newPaymentError
        )

  where try' :: forall e. Exception e => (e -> V1.WalletError) -> Maybe V1.WalletError
        try' f = f <$> fromException @e ex



createAddressErrorKernel :: Kernel.CreateAddressError -> V1.WalletError
createAddressErrorKernel e = case e of
    (Kernel.CreateAddressUnknownHdAccount _accId) ->
        V1.CannotCreateAddress (sformat build e)
    (Kernel.CreateAddressKeystoreNotFound _accId) ->
        V1.CannotCreateAddress (sformat build e)
    (Kernel.CreateAddressHdRndGenerationFailed _accId) ->
        V1.CannotCreateAddress (sformat build e)
    (Kernel.CreateAddressHdRndAddressSpaceSaturated _accId) ->
        V1.CannotCreateAddress (sformat build e)

unknownHdAccount :: HD.UnknownHdAccount -> V1.WalletError
unknownHdAccount e = case e of
    (HD.UnknownHdAccountRoot _rootId) ->
        V1.WalletNotFound
    ex@(HD.UnknownHdAccount _accId) ->
        V1.UnknownError $ (sformat build ex)

createAddressError :: CreateAddressError -> V1.WalletError
createAddressError e = case e of
    (CreateAddressError ex) ->
        createAddressErrorKernel ex
    ex@(CreateAddressAddressDecodingFailed _) ->
        V1.InvalidAddressFormat (sformat build ex)

validateAddressError :: ValidateAddressError -> V1.WalletError
validateAddressError ex@(ValidateAddressDecodingFailed _) =
    V1.InvalidAddressFormat (sformat build ex)

createAccountErrorKernel :: Kernel.CreateAccountError -> V1.WalletError
createAccountErrorKernel e = case e of
        (Kernel.CreateAccountUnknownHdRoot _rootId) ->
            V1.WalletNotFound
        e' ->
            V1.UnknownError (sformat build e')

createAccountError :: CreateAccountError -> V1.WalletError
createAccountError e = case e of
    (CreateAccountError e') ->
        createAccountErrorKernel e'

    (CreateAccountWalletIdDecodingFailed _txt) ->
        V1.WalletNotFound

    (CreateAccountFirstAddressGenerationFailed e'') ->
        createAddressErrorKernel e''

getAccountError :: GetAccountError -> V1.WalletError
getAccountError e = case e of
    (GetAccountError (V1 e')) ->
        unknownHdAccount e'
    (GetAccountWalletIdDecodingFailed _txt) ->
        V1.WalletNotFound

updateAccountError :: UpdateAccountError -> V1.WalletError
updateAccountError e = case e of
    (UpdateAccountError (V1 e')) ->
        unknownHdAccount e'
    (UpdateAccountWalletIdDecodingFailed _txt) ->
        V1.WalletNotFound

deleteAccountError :: DeleteAccountError -> V1.WalletError
deleteAccountError e = case e of
    (DeleteAccountError (V1 e')) ->
        unknownHdAccount e'
    (DeleteAccountWalletIdDecodingFailed _txt) ->
        V1.WalletNotFound

getAccountsError :: GetAccountsError -> V1.WalletError
getAccountsError e = case e of
    (GetAccountsError (HD.UnknownHdRoot _rootId)) ->
            V1.WalletNotFound

    (GetAccountsWalletIdDecodingFailed _txt) ->
        V1.WalletNotFound

createWalletError :: CreateWalletError -> V1.WalletError
createWalletError e = case e of
    (CreateWalletError
        (Kernel.CreateWalletFailed
            (HD.CreateHdRootExists rootId))) ->
                V1.WalletAlreadyExists $ toRootId rootId

    (CreateWalletFirstAccountCreationFailed e') ->
                createAccountErrorKernel e'

getWalletError :: GetWalletError -> V1.WalletError
getWalletError e = case e of
    (GetWalletError
        (V1 (HD.UnknownHdRoot _rootId))) ->
            V1.WalletNotFound
    (GetWalletErrorNotFound _wid) ->
            V1.WalletNotFound
    (GetWalletWalletIdDecodingFailed _txt) ->
            V1.WalletNotFound

updateWalletError :: UpdateWalletError -> V1.WalletError
updateWalletError e = case e of
    (UpdateWalletError
        (V1 (HD.UnknownHdRoot _rootId))) ->
            V1.WalletNotFound
    (UpdateWalletErrorNotFound _wid) ->
            V1.WalletNotFound
    (UpdateWalletWalletIdDecodingFailed _txt) ->
            V1.WalletNotFound

updateWalletPasswordError :: UpdateWalletPasswordError -> V1.WalletError
updateWalletPasswordError e = case e of
    (UpdateWalletPasswordWalletIdDecodingFailed _txt) ->
            V1.WalletNotFound

    (UpdateWalletPasswordError e') -> case e' of
        ex@(Kernel.UpdateWalletPasswordOldPasswordMismatch _rootId) ->
            V1.UnknownError (sformat build ex)

        (Kernel.UpdateWalletPasswordKeyNotFound _rootId) ->
            V1.WalletNotFound

        (Kernel.UpdateWalletPasswordUnknownHdRoot (HD.UnknownHdRoot _rootId)) ->
                V1.WalletNotFound

        ex@(Kernel.UpdateWalletPasswordKeystoreChangedInTheMeantime _rootId) ->
                V1.UnknownError (sformat build ex)

deleteWalletError :: DeleteWalletError -> V1.WalletError
deleteWalletError e = case e of
    (DeleteWalletWalletIdDecodingFailed _txt) ->
            V1.WalletNotFound

    (DeleteWalletError
        (V1 (HD.UnknownHdRoot _rootId))) ->
            V1.WalletNotFound

importWalletError :: ImportWalletError -> V1.WalletError
importWalletError e = case e of
    ex@(ImportWalletFileNotFound _file) ->
        V1.UnknownError (sformat build ex)

    ex@(ImportWalletNoWalletFoundInBackup _file) ->
        V1.UnknownError (sformat build ex)

    (ImportWalletCreationFailed e') ->
        createWalletError e'

getUtxosError :: GetUtxosError -> V1.WalletError
getUtxosError e = case e of
    (GetUtxosWalletIdDecodingFailed _txt) ->
        V1.WalletNotFound

    (GetUtxosGetAccountsError
        (HD.UnknownHdRoot _rootId)) ->
            V1.WalletNotFound

    (GetUtxosCurrentAvailableUtxoError e') ->
            unknownHdAccount e'

getTxError :: GetTxError -> V1.WalletError
getTxError e = case e of
    GetTxMissingWalletIdError ->
        V1.WalletNotFound

    (GetTxAddressDecodingFailed txt) ->
        V1.InvalidAddressFormat txt

    (GetTxInvalidSortingOperation s) ->
        V1.UnknownError $ T.pack s

    (GetTxUnknownHdAccount e') ->
        unknownHdAccount e'

newPendingError :: NewPendingError -> V1.WalletError
newPendingError e = case e of
    (NewPendingUnknown e') ->
        unknownHdAccount e'

    (NewPendingFailed e') ->
        V1.UnknownError $ (sformat build e')

newForeignError :: NewForeignError -> V1.WalletError
newForeignError e = case e of
    (NewForeignUnknown e') ->
        unknownHdAccount e'

    (NewForeignFailed e') ->
        V1.UnknownError $ (sformat build e')

newTransactionError :: Kernel.NewTransactionError -> V1.WalletError
newTransactionError e = case e of
    (Kernel.NewTransactionUnknownAccount e') ->
        unknownHdAccount e'

    (Kernel.NewTransactionErrorCoinSelectionFailed e') -> case e' of
          ex@(CoinSelHardErrOutputCannotCoverFee _outputs fee) ->
                case (readMaybe $ T.unpack fee) of
                    Just coin ->
                        V1.NotEnoughMoney coin
                    Nothing ->
                        V1.UnknownError $ (sformat build ex)

          ex@(CoinSelHardErrOutputIsRedeemAddress addr) ->
                case (decodeTextAddress addr) of
                    Right addr' ->
                        V1.OutputIsRedeem (V1 addr')
                    Left _ ->
                        V1.UnknownError $ (sformat build ex)

          CoinSelHardErrCannotCoverFee ->
                V1.NotEnoughMoney (-1)

          (CoinSelHardErrMaxInputsReached _txt) ->
                V1.TooBigTransaction

          ex@(CoinSelHardErrUtxoExhausted balance _payment) ->
              case (readMaybe $ T.unpack balance) of
                  Just coin ->
                      V1.NotEnoughMoney coin
                  Nothing ->
                      V1.UnknownError $ (sformat build ex)

          CoinSelHardErrUtxoDepleted ->
            V1.NotEnoughMoney (-1)

    (Kernel.NewTransactionErrorCreateAddressFailed e') ->
        createAddressErrorKernel e'

    (Kernel.NewTransactionErrorSignTxFailed e') -> case e' of
        (Kernel.SignTransactionMissingKey addr) ->
            V1.TxSafeSignerNotFound (V1 addr)
        (Kernel.SignTransactionErrorUnknownAddress _addr) ->
            V1.AddressNotFound
        (Kernel.SignTransactionErrorNotOwned addr) ->
            V1.TxSafeSignerNotFound (V1 addr)

    Kernel.NewTransactionInvalidTxIn ->
            V1.SignedTxSubmitError "NewTransactionInvalidTxIn"

redeemAdaError :: RedeemAdaError -> V1.WalletError
redeemAdaError e = case e of
    (RedeemAdaError e') -> case e' of
        (Kernel.RedeemAdaUnknownAccountId e'') ->
            unknownHdAccount e''

        (Kernel.RedeemAdaErrorCreateAddressFailed e'') ->
            createAddressErrorKernel e''

        (Kernel.RedeemAdaNotAvailable _addr) ->
            V1.TxRedemptionDepleted

        ex@(Kernel.RedeemAdaMultipleOutputs _addr) ->
            V1.UnknownError $ (sformat build ex)

        Kernel.RedeemAdaNewForeignFailed e'' ->
            newForeignError e''

    (RedeemAdaWalletIdDecodingFailed _txt) ->
            V1.WalletNotFound

    (RedeemAdaInvalidRedemptionCode _) ->
        V1.TxRedemptionDepleted

estimateFeesError :: EstimateFeesError -> V1.WalletError
estimateFeesError e = case e of
    (EstimateFeesError (Kernel.EstFeesTxCreationFailed e')) ->
            newTransactionError e'

    ex@(EstimateFeesTimeLimitReached _) ->
            V1.UnknownError $ (sformat build ex)

    (EstimateFeesWalletIdDecodingFailed _txt) ->
            V1.WalletNotFound

newPaymentError :: NewPaymentError -> V1.WalletError
newPaymentError e = case e of
    (NewPaymentError e') -> case e' of
        (Kernel.PaymentNewTransactionError e'') ->
            newTransactionError e''
        (Kernel.PaymentNewPendingError e'') ->
            newPendingError e''
        ex@(Kernel.PaymentSubmissionMaxAttemptsReached) ->
            V1.UnknownError $ (sformat build ex)

    ex@(NewPaymentTimeLimitReached _) ->
            V1.UnknownError $ (sformat build ex)

    (NewPaymentWalletIdDecodingFailed _txt) ->
            V1.WalletNotFound

    (NewPaymentUnknownAccountId e') ->
        unknownHdAccount e'